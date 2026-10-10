/** 实名分级、支付密码、提现（风控 + 人工审核 + 打款）、内容社区、AI 助手 */
import crypto from 'node:crypto';
import { all, bizNo, getSetting, nowIso, one, r2, run, tx } from '../db.js';
import { E } from '../errors.js';
import { hashPassword, checkPassword } from '../auth.js';
import { dpSummary, issueDp, notify, postLedger, walletChange } from './finance.js';
import { evalRisk } from './risk.js';

// ───────────────────────── KYC ─────────────────────────
export const KYC = { 1: '手机认证', 2: '实名认证', 3: '活体认证', 4: '银行卡认证' };
export const KYC_UNLOCK = { 1: '浏览、购物、接简单任务', 2: '接大部分任务、发布内容', 3: '接高额任务', 4: '提现到银行卡' };

export function kycOf(uid) {
  let k = one('SELECT * FROM kyc WHERE user_id = ?', uid);
  if (!k) {
    run('INSERT INTO kyc (user_id, level, updated_at) VALUES (?,1,?)', uid, nowIso());
    k = one('SELECT * FROM kyc WHERE user_id = ?', uid);
  }
  const { pay_pwd, ...rest } = k;
  return { ...rest, has_pay_pwd: !!pay_pwd, level_name: KYC[k.level], levels: Object.entries(KYC).map(([l, n]) => ({ level: +l, name: n, unlock: KYC_UNLOCK[l], done: k.level >= +l })) };
}

const idOk = (id) => {
  if (!/^\d{17}[\dXx]$/.test(id)) return false;
  const w = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
  const c = '10X98765432';
  const s = [...id.slice(0, 17)].reduce((a, d, i) => a + Number(d) * w[i], 0);
  return c[s % 11] === id[17].toUpperCase();
};
const luhn = (n) => {
  const d = String(n).replace(/\D/g, '');
  if (d.length < 15 || d.length > 19) return false;
  let s = 0;
  for (let i = 0; i < d.length; i++) {
    let x = Number(d[d.length - 1 - i]);
    if (i % 2) { x *= 2; if (x > 9) x -= 9; }
    s += x;
  }
  return s % 10 === 0;
};

export function kycStep(uid, step, b) {
  return tx(() => {
    const k = kycOf(uid);
    const at = nowIso();
    if (step === 'realname') {
      const name = String(b.real_name || '').trim();
      const id = String(b.id_no || '').trim();
      if (!/^[\u4e00-\u9fa5·]{2,15}$/.test(name)) throw E.bad('请输入正确的中文姓名');
      if (!idOk(id)) throw E.bad('身份证号校验失败，请检查');
      run('UPDATE kyc SET level = MAX(level, 2), real_name = ?, id_no_mask = ?, updated_at = ? WHERE user_id = ?', name, `${id.slice(0, 3)}***********${id.slice(-4)}`, at, uid);
    } else if (step === 'liveness') {
      if (k.level < 2) throw E.bad('请先完成实名认证');
      run('UPDATE kyc SET level = MAX(level, 3), updated_at = ? WHERE user_id = ?', at, uid);
    } else if (step === 'bankcard') {
      if (k.level < 3) throw E.bad('请先完成活体认证');
      const card = String(b.card_no || '').replace(/\s/g, '');
      if (!luhn(card)) throw E.bad('银行卡号校验失败');
      const bank = String(b.bank_name || '').trim() || '招商银行';
      run('UPDATE kyc SET level = 4, bank_name = ?, card_mask = ?, updated_at = ? WHERE user_id = ?', bank, `**** ${card.slice(-4)}`, at, uid);
    } else if (step === 'paypwd') {
      const p = String(b.pay_pwd || '');
      if (!/^\d{6}$/.test(p)) throw E.bad('支付密码为 6 位数字');
      if (/^(\d)\1{5}$/.test(p) || '0123456789'.includes(p) || '9876543210'.includes(p)) throw E.bad('支付密码过于简单');
      run('UPDATE kyc SET pay_pwd = ?, updated_at = ? WHERE user_id = ?', hashPassword(p), at, uid);
    } else throw E.bad('未知认证步骤');
    return kycOf(uid);
  });
}

// ───────────────────────── 提现 ─────────────────────────
export const WD_STATUS = { 10: '审核中', 20: '打款中', 30: '已到账', 90: '已退回' };

export function requestWithdraw(user, b) {
  return tx(() => {
    const k = one('SELECT * FROM kyc WHERE user_id = ?', user.id);
    if (!k || k.level < 4) throw E.forbidden('提现需先完成银行卡认证');
    if (!k.pay_pwd) throw E.forbidden('请先设置支付密码');
    if (!checkPassword(String(b.pay_pwd || ''), k.pay_pwd)) throw E.bad('支付密码错误');
    const amount = r2(Number(b.amount));
    const min = getSetting('withdraw_min', 10);
    if (!(amount >= min)) throw E.bad(`单笔最低提现 ¥${min}`);
    const fee = r2(Math.max(0, amount * getSetting('withdraw_fee_pct', 0) / 100));
    const risk = evalRisk('withdraw', user.id, { amount });
    if (risk.action === 'block') throw E.forbidden('该笔提现存在风险，已被拦截，请联系客服');
    walletChange(user.id, -amount, 'withdraw', `提现至 ${k.bank_name} ${k.card_mask}`, null);
    const no = bizNo('WD');
    const auto = risk.action === 'pass' && amount <= getSetting('withdraw_auto_max', 500);
    const at = nowIso();
    const r = run('INSERT INTO withdrawals (withdraw_no, user_id, amount, fee, bank_name, card_mask, status, risk_score, risk_hits, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', no, user.id, amount, fee, k.bank_name, k.card_mask, auto ? 30 : 10, risk.score, JSON.stringify(risk.hits), at, at);
    postLedger('withdraw', no, [[`用户钱包·U${user.id}`, 'D', amount], [auto ? '提现出款·银行' : '提现待出款', 'C', amount]]);
    notify(user.id, auto ? '提现已到账' : '提现申请已提交', auto ? `¥${amount.toFixed(2)} 已转入 ${k.bank_name} ${k.card_mask}` : `¥${amount.toFixed(2)} 正在审核，通常 2 小时内处理`);
    for (const h of risk.hits) run('UPDATE risk_cases SET ref_type = ?, ref_id = ? WHERE id = ?', 'withdrawal', Number(r.lastInsertRowid), h.case_id);
    return one('SELECT * FROM withdrawals WHERE id = ?', Number(r.lastInsertRowid));
  });
}

export function processWithdraw(id, action, note) {
  return tx(() => {
    const w = one('SELECT * FROM withdrawals WHERE id = ?', id);
    if (!w) throw E.notFound('提现单不存在');
    const at = nowIso();
    if (action === 'approve') {
      if (w.status !== 10) throw E.conflict('不在审核中');
      run('UPDATE withdrawals SET status = 30, updated_at = ? WHERE id = ?', at, id);
      postLedger('withdraw_pay', w.withdraw_no, [['提现待出款', 'D', w.amount], ['提现出款·银行', 'C', w.amount]]);
      notify(w.user_id, '提现已到账', `¥${w.amount.toFixed(2)} 已转入 ${w.bank_name} ${w.card_mask}`);
    } else if (action === 'reject') {
      if (w.status !== 10) throw E.conflict('不在审核中');
      run('UPDATE withdrawals SET status = 90, reject_reason = ?, updated_at = ? WHERE id = ?', note || '审核未通过', at, id);
      walletChange(w.user_id, w.amount, 'withdraw_refund', `提现退回 · ${note || ''}`, w.withdraw_no);
      postLedger('withdraw_refund', w.withdraw_no, [['提现待出款', 'D', w.amount], [`用户钱包·U${w.user_id}`, 'C', w.amount]]);
      notify(w.user_id, '提现已退回', `¥${w.amount.toFixed(2)} 已退回钱包：${note || '审核未通过'}`);
    } else throw E.bad('未知操作');
    return one('SELECT * FROM withdrawals WHERE id = ?', id);
  });
}

// ───────────────────────── 内容社区 ─────────────────────────
export const POST_STATUS = { 0: '审核中', 1: '已发布', 2: '精选', 9: '未通过' };

export function postView(p, uid) {
  const u = one('SELECT nickname, ext_id, labor_level FROM users WHERE id = ?', p.user_id);
  return { ...p, images: JSON.parse(p.images || '[]'), tags: JSON.parse(p.tags || '[]'), author: u?.nickname, author_level: u?.labor_level, status_label: POST_STATUS[p.status], liked: uid ? !!one('SELECT 1 x FROM post_likes WHERE post_id = ? AND user_id = ?', p.id, uid) : false };
}

export function createPost(user, b) {
  return tx(() => {
    if (kycOf(user.id).level < 2) throw E.forbidden('发布内容需先完成实名认证');
    const title = String(b.title || '').trim();
    const body = String(b.body || '').trim();
    if (title.length < 4 || title.length > 60) throw E.bad('标题 4~60 字');
    if (body.length < 10 || body.length > 5000) throw E.bad('正文 10~5000 字');
    const risk = evalRisk('content', user.id, { text: `${title}\n${body}` });
    const status = risk.action === 'block' ? 9 : risk.action === 'review' ? 0 : 1;
    const r = run('INSERT INTO posts (user_id, title, body, images, tags, task_order_id, ai_generated, status, ai_score, block_reason, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', user.id, title, body, JSON.stringify((b.images || []).slice(0, 9)), JSON.stringify((b.tags || []).slice(0, 5)), b.task_order_id || null, b.ai_generated ? 1 : 0, status, 100 - risk.score, risk.action === 'block' ? risk.hits.map((h) => h.name).join('、') : null, nowIso());
    const id = Number(r.lastInsertRowid);
    for (const h of risk.hits) run('UPDATE risk_cases SET ref_type = ?, ref_id = ? WHERE id = ?', 'post', id, h.case_id);
    return postView(one('SELECT * FROM posts WHERE id = ?', id), user.id);
  });
}

export function moderatePost(id, action, note) {
  const p = one('SELECT * FROM posts WHERE id = ?', id);
  if (!p) throw E.notFound('内容不存在');
  const st = { approve: 1, feature: 2, block: 9 }[action];
  if (st == null) throw E.bad('未知操作');
  run('UPDATE posts SET status = ?, block_reason = ? WHERE id = ?', st, action === 'block' ? note || '违反社区规范' : null, id);
  notify(p.user_id, st === 9 ? '内容未通过审核' : '内容已发布', st === 9 ? `「${p.title}」：${note || '违反社区规范'}` : `「${p.title}」${st === 2 ? '被评为精选，' : ''}已发布`);
  return one('SELECT * FROM posts WHERE id = ?', id);
}

export function likePost(uid, id) {
  return tx(() => {
    const p = one('SELECT * FROM posts WHERE id = ? AND status IN (1,2)', id);
    if (!p) throw E.notFound('内容不存在');
    if (one('SELECT 1 x FROM post_likes WHERE post_id = ? AND user_id = ?', id, uid)) {
      run('DELETE FROM post_likes WHERE post_id = ? AND user_id = ?', id, uid);
      run('UPDATE posts SET likes = MAX(0, likes - 1) WHERE id = ?', id);
    } else {
      run('INSERT INTO post_likes (post_id, user_id, created_at) VALUES (?,?,?)', id, uid, nowIso());
      run('UPDATE posts SET likes = likes + 1 WHERE id = ?', id);
    }
    return postView(one('SELECT * FROM posts WHERE id = ?', id), uid);
  });
}

/** 内容激励结算：按互动量计收益，按平台比例拆成现金 + 清偿金（后台/定时任务触发） */
export function settleContentRevenue() {
  return tx(() => {
    const per = getSetting('content_rev_per_like', 0.05);
    const cashPct = getSetting('content_cash_pct', 40);
    let n = 0;
    for (const p of all('SELECT * FROM posts WHERE status IN (1,2)')) {
      const due = r2((p.likes * per + p.comments * per * 2 + p.views * 0.001) * (p.status === 2 ? 1.5 : 1) - p.revenue);
      if (due < 0.5) continue;
      const cash = r2((due * cashPct) / 100);
      const clear = r2(due - cash);
      if (cash > 0) walletChange(p.user_id, cash, 'content_income', `内容激励 · ${p.title}`, `POST-${p.id}`);
      if (clear > 0) issueDp(p.user_id, 'content', clear, clear, 'post', p.id, `内容激励 · ${p.title}`);
      postLedger('content_revenue', `POST-${p.id}`, [['平台内容激励费用', 'D', due], [`用户钱包·U${p.user_id}`, 'C', cash], [`债务积分现金备付金·U${p.user_id}`, 'C', clear]]);
      run('UPDATE posts SET revenue = revenue + ? WHERE id = ?', due, p.id);
      n++;
    }
    return { settled: n };
  });
}

// ───────────────────────── AI 助手 ─────────────────────────
export const AGENTS = {
  planner: { name: '清偿规划师', icon: '🧭', intro: '帮你排清偿顺序、算多久能偿清', prompts: ['我先清偿哪一笔最划算？', '按现在的速度多久能全部偿清？', '怎样让清偿金来得更快？'] },
  matcher: { name: '任务匹配助手', icon: '🎯', intro: '根据你的时间和技能推荐微劳动', prompts: ['我每天只有 1 小时，适合做什么？', '推荐几个今天就能完成的任务', '我会剪视频，有什么高报酬任务？'] },
  writer: { name: '创作助手', icon: '✍️', intro: '帮你写种草文案、改标题、起脚本', prompts: ['帮我写一段护肤品种草文案', '把这个标题改得更吸引人', '给我一个 30 秒短视频脚本'] },
};

function context(uid) {
  const u = one('SELECT * FROM users WHERE id = ?', uid);
  const dp = dpSummary(uid);
  const debts = all('SELECT creditor, outstanding, debt_type FROM debt_cases WHERE user_id = ? AND status != 3 ORDER BY outstanding ASC', uid);
  const tasks = all('SELECT id, title, reward, task_type, kyc_required FROM tasks WHERE status = 2 ORDER BY reward DESC LIMIT 30');
  const labor = one('SELECT COALESCE(SUM(clear_amount),0) c, COUNT(*) n FROM task_orders WHERE user_id = ? AND status = 80 AND settled_at > ?', uid, new Date(Date.now() - 30 * 86400_000).toISOString());
  const shop = one("SELECT COALESCE(SUM(dp_amount),0) c FROM commissions WHERE user_id = ? AND status = 2 AND settled_at > ?", uid, new Date(Date.now() - 30 * 86400_000).toISOString());
  return { u, dp, debts, tasks, monthly: r2(labor.c + shop.c), laborN: labor.n, kyc: kycOf(uid).level };
}

/** 无大模型 key 时的规则答复；配置 AI_API_KEY 后走 OpenAI 兼容接口 */
function ruleReply(agent, q, c) {
  const money = (v) => `¥${Number(v).toLocaleString('zh-CN', { maximumFractionDigits: 2 })}`;
  if (agent === 'planner') {
    if (!c.debts.length) return '你还没有接入待清偿账单。先到「查询银行账单」输入手机号，我就能帮你排清偿顺序了。';
    const total = c.debts.reduce((a, d) => a + d.outstanding, 0);
    const first = c.debts[0];
    const speed = Math.max(c.monthly, 200);
    const months = Math.ceil(total / speed);
    if (/多久|多长时间|速度/.test(q)) return `你目前共有 ${c.debts.length} 笔待清偿，合计 ${money(total)}。\n\n按近 30 天的节奏（每月约 ${money(speed)} 清偿金），大约需要 ${months} 个月全部偿清。\n\n想再快一点：\n· 每天做 1 个微劳动任务，每月可多 ${money(300)}~${money(1200)}\n· 日常买咖啡、买菜、缴话费都在星光云下单\n· 每次清偿都会让信用分上涨，返还倍率也会随之提高`;
    if (/快|更多/.test(q)) return `让清偿金来得更快的三个办法：\n\n1. 微劳动：选「清偿金比例高」的任务，比如问卷、内容种草，${c.kyc < 2 ? '先完成实名认证能解锁更多任务' : '你已实名，可以接大部分任务'}\n2. 日常消费：本来就要买的东西，在商城买，每单都返\n3. 提升信用：按时清偿，信用分 ${c.u.credit_score} → 650 以上，返还倍率 +1.0`;
    return `建议先清偿「${first.creditor}」（剩余 ${money(first.outstanding)}），它是金额最小的一笔。\n\n先偿清小额账单，能最快拿到银行的《偿清证明》，信用分 +15，后面的返还倍率也会更高。你现在有 ${money(c.dp.available)} 清偿金${c.dp.available >= first.outstanding ? '，已经够把这笔一次偿清了！' : `，还差 ${money(first.outstanding - c.dp.available)}。`}`;
  }
  if (agent === 'matcher') {
    const ok = c.tasks.filter((t) => t.kyc_required <= c.kyc);
    const quick = ok.filter((t) => ['survey', 'label', 'promo'].includes(t.task_type)).slice(0, 3);
    const high = ok.filter((t) => ['content', 'skill'].includes(t.task_type)).slice(0, 3);
    const list = (/视频|剪|高报酬|技能/.test(q) ? high : quick.length ? quick : ok.slice(0, 3));
    if (!list.length) return c.kyc < 2 ? '完成实名认证后可以解锁更多任务，去「我的 → 实名与安全」认证只要 1 分钟。' : '暂时没有合适的任务，稍后再来看看。';
    return `根据你的情况，推荐这几个：\n\n${list.map((t, i) => `${i + 1}. ${t.title} · ${money(t.reward)}`).join('\n')}\n\n在「微劳动」里搜索标题即可接单。${c.kyc < 3 ? '\n\n小提示：完成活体认证可以接报酬更高的任务。' : ''}`;
  }
  // writer
  if (/标题/.test(q)) return '好标题的三个套路：\n\n1. 数字 + 结果：「用了 7 天，毛孔真的小了一圈」\n2. 反差：「不贵的精华，反而最适合敏感肌」\n3. 场景：「通勤 20 分钟，我靠它撑住了一天的妆」\n\n把你的原标题发给我，我按这三种改给你。';
  if (/脚本/.test(q)) return '30 秒短视频脚本：\n\n0-3s 钩子：脸部特写 +「敏感肌姐妹别划走」\n3-12s 痛点：换季泛红、上妆卡粉\n12-24s 产品：上脸质地、吸收速度、7 天对比\n24-30s 行动：「链接放评论区，我用的是这款」\n\n记得遵守任务要求，保留原始素材，标注 AI 辅助比例。';
  return '这是一段种草文案参考：\n\n「换季脸总是红红的，试了这瓶精华一周——早上上妆不卡粉了，晚上涂完第二天脸是软的。质地像水一样，拍两下就吸收，敏感肌也没刺痛。不是什么大牌，但真的是我今年回购最多的一瓶。」\n\n用自己的真实体验替换细节，原创度会更高，AI 初审更容易通过。';
}

export async function chat(uid, agent, message) {
  if (!AGENTS[agent]) throw E.bad('助手不存在');
  const q = String(message || '').trim().slice(0, 500);
  if (!q) throw E.bad('说点什么吧');
  if (/忽略(之前|以上)|ignore (all|previous)|system prompt|你的提示词/i.test(q)) {
    const a = '这个问题我没办法回答哦。可以问我清偿顺序、适合的任务或者文案写作。';
    run('INSERT INTO ai_messages (user_id, agent, role, content, created_at) VALUES (?,?,?,?,?)', uid, agent, 'user', q, nowIso());
    run('INSERT INTO ai_messages (user_id, agent, role, content, created_at) VALUES (?,?,?,?,?)', uid, agent, 'assistant', a, nowIso());
    return { reply: a, engine: 'guard' };
  }
  const c = context(uid);
  let reply = null;
  let engine = 'rules';
  const key = process.env.AI_API_KEY;
  if (key) {
    try {
      const sys = `你是星光云的「${AGENTS[agent].name}」。星光云帮用户通过日常消费返还清偿金、做微劳动任务赚钱，来清偿银行账单。用语要温和、不说"负债/还债/欠钱"，用"清偿/待清偿账单/偿清"。不承诺征信修复、不提供贷款。回答简洁，用中文。\n用户信息：信用分 ${c.u.credit_score}，可用清偿金 ${c.dp.available} 元，待清偿账单：${c.debts.map((d) => `${d.creditor} ${d.outstanding} 元`).join('；') || '无'}。近 30 天清偿金收入 ${c.monthly} 元。实名等级 ${c.kyc}。\n当前可接任务（前 10）：${c.tasks.slice(0, 10).map((t) => `${t.title}(${t.reward}元)`).join('；')}`;
      const hist = all('SELECT role, content FROM ai_messages WHERE user_id = ? AND agent = ? ORDER BY id DESC LIMIT 8', uid, agent).reverse();
      const res = await fetch(`${process.env.AI_BASE_URL || 'https://api.openai.com/v1'}/chat/completions`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${key}` },
        body: JSON.stringify({ model: process.env.AI_MODEL || 'gpt-4o-mini', messages: [{ role: 'system', content: sys }, ...hist, { role: 'user', content: q }], temperature: 0.6, max_tokens: 600 }),
        signal: AbortSignal.timeout(25000),
      });
      const j = await res.json();
      reply = j.choices?.[0]?.message?.content?.trim() || null;
      if (reply) engine = 'llm';
    } catch (e) {
      console.error('[ai]', e.message);
    }
  }
  if (!reply) reply = ruleReply(agent, q, c);
  run('INSERT INTO ai_messages (user_id, agent, role, content, created_at) VALUES (?,?,?,?,?)', uid, agent, 'user', q, nowIso());
  run('INSERT INTO ai_messages (user_id, agent, role, content, created_at) VALUES (?,?,?,?,?)', uid, agent, 'assistant', reply, nowIso());
  return { reply, engine };
}

void crypto;
