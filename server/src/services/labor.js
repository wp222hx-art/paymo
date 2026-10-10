/**
 * 微劳动：商家发布任务（押金托管）→ 用户接单 → 提交交付物 → AI 原创初审 → 商家验收（超时自动通过）
 *        → 结算分账（平台服务费 / 可提现现金 / 清偿金）；驳回可申诉，平台仲裁。
 */
import crypto from 'node:crypto';
import { all, bizNo, getSetting, nowIso, one, r2, run, tx } from '../db.js';
import { E } from '../errors.js';
import { issueDp, notify, postLedger, quoteMultiplier, walletChange } from './finance.js';
import { evalRisk } from './risk.js';

export const TASK_TYPES = {
  content: { name: '内容种草', icon: '🎬', img: 'labor_content' },
  survey: { name: '问卷调研', icon: '📝', img: 'labor_survey' },
  visit: { name: '门店探访', icon: '📍', img: 'labor_visit' },
  service: { name: '线上客服', icon: '🎧', img: 'labor_service' },
  promo: { name: '社群推广', icon: '📣', img: 'labor_promo' },
  skill: { name: '技能服务', icon: '🛠️', img: 'labor_skill' },
  label: { name: '数据标注', icon: '🏷️', img: 'labor_label' },
  errand: { name: '同城跑腿', icon: '🛵', img: 'labor_delivery' },
};
export const TASK_STATUS = { 0: '草稿', 1: '审核中', 2: '招募中', 3: '已满员', 4: '已结束', 6: '已下架', 8: '审核驳回' };
export const ORDER_STATUS = { 10: '已接单', 20: '进行中', 40: 'AI 初审中', 45: '需修改后重交', 50: '待商家验收', 55: '申诉中', 60: '已通过', 70: '未通过', 80: '已结算', 31: '已超时', 32: '已放弃' };
const ACTIVE = [10, 20, 40, 45, 50, 55];
const KYC_NAME = { 1: '手机认证', 2: '实名认证', 3: '活体认证', 4: '银行卡认证' };

const pushHist = (o, status, note, op) => {
  const h = JSON.parse(o.history_json || '[]');
  h.push({ status, note, operator: op, at: nowIso() });
  return JSON.stringify(h);
};

export const kycLevel = (uid) => one('SELECT level FROM kyc WHERE user_id = ?', uid)?.level ?? 1;

export function taskView(t, uid) {
  const v = { ...t, type_name: TASK_TYPES[t.task_type]?.name, type_icon: TASK_TYPES[t.task_type]?.icon, status_label: TASK_STATUS[t.status], requirements: JSON.parse(t.requirements || '[]'), tags: JSON.parse(t.tags || '[]'), left: Math.max(0, t.quota - t.taken) };
  const net = r2(t.reward * (1 - t.fee_pct / 100));
  v.est_cash = r2((net * t.cash_pct) / (t.cash_pct + t.clear_pct || 1));
  v.est_clear_cash = r2(net - v.est_cash);
  if (uid) {
    const u = one('SELECT credit_score FROM users WHERE id = ?', uid);
    const m = t.boost ? laborMultiplier(u.credit_score) : 1;
    v.est_multiplier = m;
    v.est_clear = r2(v.est_clear_cash * m);
    v.my_order = one(`SELECT id, order_no, status FROM task_orders WHERE task_id = ? AND user_id = ? ORDER BY id DESC LIMIT 1`, t.id, uid) || null;
    const k = kycLevel(uid);
    v.eligible = k >= t.kyc_required && u.credit_score >= t.credit_min;
    v.ineligible_reason = k < t.kyc_required ? `需完成${KYC_NAME[t.kyc_required]}` : u.credit_score < t.credit_min ? `需信用分 ≥ ${t.credit_min}` : null;
  }
  return v;
}

/** 微劳动清偿金加成：只取信用分加成部分（1 + bonus），并受全局上限约束 */
export function laborMultiplier(creditScore) {
  const q = quoteMultiplier(-1, creditScore);
  return r2(Math.min(1 + q.bonus, q.cap));
}

export function orderView(o) {
  const t = one('SELECT * FROM tasks WHERE id = ?', o.task_id);
  const u = one('SELECT nickname, credit_score FROM users WHERE id = ?', o.user_id);
  return { ...o, status_label: ORDER_STATUS[o.status], history: JSON.parse(o.history_json || '[]'), submission_files: JSON.parse(o.submission_files || '[]'), ai_report: o.ai_report ? JSON.parse(o.ai_report) : null, task: t ? taskView(t) : null, worker: u };
}

// ───────────────────────── 商家：发布 / 下架 ─────────────────────────

export function publishTask(merchant, b) {
  return tx(() => {
    if (merchant.role !== 'merchant') throw E.forbidden('仅商家账号可发布任务');
    const type = String(b.task_type);
    if (!TASK_TYPES[type]) throw E.bad('任务类型无效');
    const reward = r2(Number(b.reward));
    const quota = Number(b.quota);
    if (!(reward >= 1 && reward <= 50000)) throw E.bad('单份报酬需在 1~50000 元');
    if (!Number.isInteger(quota) || quota < 1 || quota > 10000) throw E.bad('名额需为 1~10000');
    const cash = Number(b.cash_pct ?? 40);
    const clear = Number(b.clear_pct ?? 100 - cash);
    if (cash < 0 || clear < 0 || Math.abs(cash + clear - 100) > 0.01) throw E.bad('现金与清偿金比例之和需为 100%');
    const title = String(b.title || '').trim();
    if (title.length < 4 || title.length > 60) throw E.bad('标题 4~60 字');
    const desc = String(b.description || '').trim();
    if (desc.length < 10) throw E.bad('任务说明至少 10 字');
    const deposit = r2(reward * quota);
    walletChange(merchant.id, -deposit, 'task_deposit', `任务押金托管 · ${title}`, null);
    run('UPDATE users SET wallet_frozen = wallet_frozen + ? WHERE id = ?', deposit, merchant.id);
    const at = nowIso();
    const days = Math.min(90, Math.max(1, Number(b.days ?? 14)));
    const no = bizNo('TK');
    const r = run(
      `INSERT INTO tasks (task_no, publisher_id, publisher_name, task_type, title, description, requirements, image, reward, cash_pct, clear_pct, fee_pct, boost, quota, kyc_required, credit_min, duration_hours, review_hours, tags, city, deposit, deposit_left, status, deadline_at, created_at, updated_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,?,?,?)`,
      no, merchant.id, merchant.org_name || merchant.nickname, type, title, desc, JSON.stringify((b.requirements || []).map(String).slice(0, 10)), b.image || `/media/img/${TASK_TYPES[type].img}.webp`, reward, cash, clear, getSetting('task_fee_pct', 10), b.boost === false ? 0 : 1, quota,
      Math.min(4, Math.max(1, Number(b.kyc_required ?? 2))), Number(b.credit_min ?? 0), Number(b.duration_hours ?? 72), Number(b.review_hours ?? 72), JSON.stringify((b.tags || []).slice(0, 6)), b.city || null, deposit, deposit,
      new Date(Date.now() + days * 86400_000).toISOString(), at, at,
    );
    const id = Number(r.lastInsertRowid);
    postLedger('task_deposit', no, [[`商家钱包·U${merchant.id}`, 'D', deposit], [`任务押金托管·${no}`, 'C', deposit]]);
    // 自动审核：命中敏感词进入人工审核，否则直接上架
    const bad = /征信修复|内部渠道|消除逾期|刷单|加微信|兼职日结|垫付/.test(`${title}${desc}`);
    if (!bad && getSetting('task_auto_approve', 1)) run('UPDATE tasks SET status = 2 WHERE id = ?', id);
    return taskView(one('SELECT * FROM tasks WHERE id = ?', id));
  });
}

export function auditTask(id, approve, reason, op) {
  return tx(() => {
    const t = one('SELECT * FROM tasks WHERE id = ?', id);
    if (!t) throw E.notFound('任务不存在');
    if (t.status !== 1) throw E.conflict('任务不在审核中');
    if (approve) {
      run('UPDATE tasks SET status = 2, updated_at = ? WHERE id = ?', nowIso(), id);
      notify(t.publisher_id, '任务已上架', `「${t.title}」审核通过，开始招募。`);
    } else {
      run('UPDATE tasks SET status = 8, reject_reason = ?, updated_at = ? WHERE id = ?', reason || '不符合平台规范', nowIso(), id);
      refundDeposit(t, `审核驳回：${reason || ''}`);
    }
    void op;
    return one('SELECT * FROM tasks WHERE id = ?', id);
  });
}

function refundDeposit(t, why) {
  const left = one('SELECT deposit_left FROM tasks WHERE id = ?', t.id).deposit_left;
  if (left <= 0.005) return 0;
  run('UPDATE tasks SET deposit_left = 0 WHERE id = ?', t.id);
  run('UPDATE users SET wallet_frozen = MAX(0, wallet_frozen - ?) WHERE id = ?', left, t.publisher_id);
  walletChange(t.publisher_id, left, 'task_refund', `任务押金退回 · ${t.title}`, t.task_no);
  postLedger('task_refund', t.task_no, [[`任务押金托管·${t.task_no}`, 'D', left], [`商家钱包·U${t.publisher_id}`, 'C', left]]);
  notify(t.publisher_id, '押金已退回', `「${t.title}」剩余押金 ¥${left.toFixed(2)} 已退回钱包（${why}）。`);
  return left;
}

export function closeTask(merchantId, id) {
  return tx(() => {
    const t = one('SELECT * FROM tasks WHERE id = ? AND publisher_id = ?', id, merchantId);
    if (!t) throw E.notFound('任务不存在');
    if (![1, 2, 3].includes(t.status)) throw E.conflict('任务已结束');
    if (one(`SELECT id FROM task_orders WHERE task_id = ? AND status IN (${ACTIVE.join(',')}) LIMIT 1`, id)) throw E.conflict('还有进行中的任务单，请处理完再下架');
    run('UPDATE tasks SET status = 6, updated_at = ? WHERE id = ?', nowIso(), id);
    refundDeposit(t, '商家下架');
    return one('SELECT * FROM tasks WHERE id = ?', id);
  });
}

// ───────────────────────── 用户：接单 / 提交 / 放弃 / 申诉 ─────────────────────────

export function acceptTask(user, taskId) {
  return tx(() => {
    const t = one('SELECT * FROM tasks WHERE id = ?', taskId);
    if (!t) throw E.notFound('任务不存在');
    if (t.status !== 2) throw E.conflict('任务暂未在招募');
    if (t.deadline_at < nowIso()) throw E.conflict('任务已截止');
    if (t.publisher_id === user.id) throw E.forbidden('不能接自己发布的任务');
    if (user.role !== 'user') throw E.forbidden('当前账号类型不能接单');
    const k = kycLevel(user.id);
    if (k < t.kyc_required) throw E.forbidden(`该任务需要先完成${KYC_NAME[t.kyc_required]}`);
    if (user.credit_score < t.credit_min) throw E.forbidden(`该任务要求信用分 ≥ ${t.credit_min}`);
    if (one(`SELECT id FROM task_orders WHERE task_id = ? AND user_id = ? AND status IN (${[...ACTIVE, 60, 80].join(',')})`, taskId, user.id)) throw E.conflict('你已接过这个任务');
    const n = one(`SELECT COUNT(*) n FROM task_orders WHERE user_id = ? AND status IN (${ACTIVE.join(',')})`, user.id).n;
    const max = getSetting('task_max_active', 5);
    if (n >= max) throw E.conflict(`同时进行的任务最多 ${max} 个，先完成手头的吧`);
    const u = run('UPDATE tasks SET taken = taken + 1, status = CASE WHEN taken + 1 >= quota THEN 3 ELSE status END, updated_at = ? WHERE id = ? AND taken < quota', nowIso(), taskId);
    if (u.changes === 0) throw E.conflict('名额已满');
    const at = nowIso();
    const no = bizNo('TO');
    const hist = JSON.stringify([{ status: 20, note: '接单成功', operator: `USER:${user.id}`, at }]);
    const r = run('INSERT INTO task_orders (order_no, task_id, user_id, status, history_json, due_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)', no, taskId, user.id, 20, hist, new Date(Date.now() + t.duration_hours * 3600_000).toISOString(), at, at);
    return orderView(one('SELECT * FROM task_orders WHERE id = ?', Number(r.lastInsertRowid)));
  });
}

/** AI 原创初审（规则引擎模拟：长度、敏感词、重复度、链接有效性） */
export function aiReview(task, text, link, files, userId) {
  const reasons = [];
  let score = 92;
  const t = String(text || '');
  if (t.length < 20 && !link && !(files || []).length) { score -= 40; reasons.push('交付内容过少，请补充作品链接、截图或说明'); }
  if (/搬运|复制|copy|测试|test|随便/i.test(t)) { score -= 38; reasons.push('疑似搬运或测试内容'); }
  if (/加微信|加V|征信修复|内部渠道/i.test(t)) { score -= 55; reasons.push('含引流或违规话术'); }
  if (link && !/^https?:\/\/\S+\.\S+/.test(link)) { score -= 20; reasons.push('作品链接格式不正确'); }
  const dup = one('SELECT id FROM task_orders WHERE task_id = ? AND user_id != ? AND submission_text = ? AND submission_text IS NOT NULL LIMIT 1', task.id, userId, t);
  if (dup && t.length > 0) { score -= 45; reasons.push('与他人交付内容高度重复'); }
  const h = crypto.createHash('md5').update(`${task.id}${t}${link}`).digest()[0];
  score = Math.max(5, Math.min(99, score + (h % 7) - 3));
  return { score, pass: score >= 60, reasons, checks: [
    { name: '原创性', ok: !dup && !/搬运|复制/i.test(t) },
    { name: '内容完整度', ok: !(t.length < 20 && !link && !(files || []).length) },
    { name: '合规与引流', ok: !/加微信|加V|征信修复|内部渠道/i.test(t) },
    { name: '链接有效', ok: !link || /^https?:\/\/\S+\.\S+/.test(link) },
  ] };
}

export function submitOrder(user, orderId, b) {
  return tx(() => {
    const o = one('SELECT * FROM task_orders WHERE id = ? AND user_id = ?', orderId, user.id);
    if (!o) throw E.notFound('任务单不存在');
    if (![20, 45].includes(o.status)) throw E.conflict(`当前状态「${ORDER_STATUS[o.status]}」不能提交`);
    if (o.due_at < nowIso()) throw E.conflict('已超过交付时限');
    const t = one('SELECT * FROM tasks WHERE id = ?', o.task_id);
    const text = String(b.text || '').slice(0, 2000);
    const link = b.link ? String(b.link).slice(0, 500) : null;
    const files = (b.files || []).map(String).slice(0, 9);
    const ai = aiReview(t, text, link, files, user.id);
    const attempts = o.ai_attempts + 1;
    const maxAttempts = getSetting('task_ai_max_attempts', 3);
    const at = nowIso();
    run('UPDATE task_orders SET submission_text = ?, submission_link = ?, submission_files = ?, ai_score = ?, ai_report = ?, ai_attempts = ?, submitted_at = ?, updated_at = ? WHERE id = ?', text, link, JSON.stringify(files), ai.score, JSON.stringify(ai), attempts, at, at, o.id);
    let cur = one('SELECT * FROM task_orders WHERE id = ?', o.id);
    if (ai.pass) {
      const due = new Date(Date.now() + t.review_hours * 3600_000).toISOString();
      run('UPDATE task_orders SET status = 50, review_due_at = ?, history_json = ? WHERE id = ?', due, pushHist(cur, 50, `AI 初审通过（${ai.score} 分），等待商家验收`, 'AI'), o.id);
      notify(t.publisher_id, '有新的交付待验收', `「${t.title}」收到 ${user.nickname} 的交付，请在 ${t.review_hours} 小时内验收，超时将自动通过。`);
    } else if (attempts < maxAttempts) {
      run('UPDATE task_orders SET status = 45, history_json = ? WHERE id = ?', pushHist(cur, 45, `AI 初审未通过（${ai.score} 分）：${ai.reasons.join('；')}。还可重交 ${maxAttempts - attempts} 次`, 'AI'), o.id);
    } else {
      run('UPDATE task_orders SET status = 70, review_note = ?, history_json = ? WHERE id = ?', 'AI 初审连续未通过', pushHist(cur, 70, `AI 初审连续 ${attempts} 次未通过，可申诉`, 'AI'), o.id);
      releaseSlot(t, o);
    }
    cur = one('SELECT * FROM task_orders WHERE id = ?', o.id);
    if (ai.score < 40) evalRisk('task', user.id, { ref_type: 'task_order', ref_id: o.id, ai_score: ai.score, reasons: ai.reasons });
    return orderView(cur);
  });
}

function releaseSlot(t, o) {
  // 未完成的名额释放回任务；若任务已满员则恢复招募
  run('UPDATE tasks SET taken = MAX(0, taken - 1), status = CASE WHEN status = 3 THEN 2 ELSE status END, updated_at = ? WHERE id = ?', nowIso(), t.id);
  void o;
}

export function abandonOrder(user, orderId) {
  return tx(() => {
    const o = one('SELECT * FROM task_orders WHERE id = ? AND user_id = ?', orderId, user.id);
    if (!o) throw E.notFound('任务单不存在');
    if (![20, 45].includes(o.status)) throw E.conflict('当前状态不能放弃');
    run('UPDATE task_orders SET status = 32, history_json = ?, updated_at = ? WHERE id = ?', pushHist(o, 32, '用户放弃', `USER:${user.id}`), nowIso(), o.id);
    releaseSlot(one('SELECT * FROM tasks WHERE id = ?', o.task_id), o);
    return orderView(one('SELECT * FROM task_orders WHERE id = ?', o.id));
  });
}

/** 商家验收 */
export function reviewOrder(merchant, orderId, approve, note, rating) {
  return tx(() => {
    const o = one('SELECT o.* FROM task_orders o JOIN tasks t ON t.id = o.task_id WHERE o.id = ? AND t.publisher_id = ?', orderId, merchant.id);
    if (!o) throw E.notFound('任务单不存在');
    if (o.status !== 50) throw E.conflict('不在待验收状态');
    const t = one('SELECT * FROM tasks WHERE id = ?', o.task_id);
    if (approve) {
      run('UPDATE task_orders SET status = 60, rating = ?, review_note = ?, history_json = ?, updated_at = ? WHERE id = ?', rating ? Math.min(5, Math.max(1, Number(rating))) : null, note || null, pushHist(o, 60, `商家验收通过${note ? `：${note}` : ''}`, `MERCHANT:${merchant.id}`), nowIso(), o.id);
      return settleOrder(o.id);
    }
    if (!note || String(note).trim().length < 4) throw E.bad('驳回需写明原因（至少 4 字）');
    run('UPDATE task_orders SET status = 70, review_note = ?, history_json = ?, updated_at = ? WHERE id = ?', note, pushHist(o, 70, `商家驳回：${note}`, `MERCHANT:${merchant.id}`), nowIso(), o.id);
    releaseSlot(t, o);
    notify(o.user_id, '交付未通过', `「${t.title}」未通过验收：${note}。如有异议可在 3 天内申诉。`);
    return orderView(one('SELECT * FROM task_orders WHERE id = ?', o.id));
  });
}

export function disputeOrder(user, orderId, reason) {
  return tx(() => {
    const o = one('SELECT * FROM task_orders WHERE id = ? AND user_id = ?', orderId, user.id);
    if (!o) throw E.notFound('任务单不存在');
    if (o.status !== 70) throw E.conflict('只有未通过的任务单可以申诉');
    if (o.dispute_reason) throw E.conflict('已申诉过');
    if (!reason || String(reason).trim().length < 6) throw E.bad('请写明申诉理由（至少 6 字）');
    const t = one('SELECT * FROM tasks WHERE id = ?', o.task_id);
    // 申诉需要重新占用名额；若已满员仍允许（仲裁通过时从押金结算）
    run('UPDATE tasks SET taken = taken + 1 WHERE id = ?', t.id);
    run('UPDATE task_orders SET status = 55, dispute_reason = ?, history_json = ?, updated_at = ? WHERE id = ?', String(reason).slice(0, 500), pushHist(o, 55, `发起申诉：${reason}`, `USER:${user.id}`), nowIso(), o.id);
    notify(t.publisher_id, '交付被申诉', `「${t.title}」的一笔驳回被申诉，平台将在 48 小时内仲裁。`);
    return orderView(one('SELECT * FROM task_orders WHERE id = ?', o.id));
  });
}

/** 平台仲裁 */
export function arbitrate(orderId, approve, note, op) {
  return tx(() => {
    const o = one('SELECT * FROM task_orders WHERE id = ?', orderId);
    if (!o) throw E.notFound('任务单不存在');
    if (o.status !== 55) throw E.conflict('不在申诉中');
    const t = one('SELECT * FROM tasks WHERE id = ?', o.task_id);
    if (approve) {
      run('UPDATE task_orders SET status = 60, arbitration = ?, history_json = ? WHERE id = ?', note || '仲裁支持用户', pushHist(o, 60, `平台仲裁：支持用户${note ? `（${note}）` : ''}`, op), o.id);
      return settleOrder(o.id);
    }
    run('UPDATE task_orders SET status = 70, arbitration = ?, history_json = ? WHERE id = ?', note || '维持驳回', pushHist(o, 70, `平台仲裁：维持驳回${note ? `（${note}）` : ''}`, op), o.id);
    releaseSlot(t, o);
    notify(o.user_id, '申诉结果', `「${t.title}」仲裁结果：维持驳回。${note || ''}`);
    return orderView(one('SELECT * FROM task_orders WHERE id = ?', o.id));
  });
}

/** 结算分账：押金 → 平台服务费 + 用户现金（钱包可提现）+ 清偿金（现金背书入备付金，面值可享信用加成） */
export function settleOrder(orderId) {
  return tx(() => {
    const o = one('SELECT * FROM task_orders WHERE id = ?', orderId);
    if (o.status !== 60) throw E.conflict('任务单未通过验收');
    const t = one('SELECT * FROM tasks WHERE id = ?', o.task_id);
    const u = one('SELECT * FROM users WHERE id = ?', o.user_id);
    const gross = t.reward;
    if (t.deposit_left < gross - 0.005) throw E.conflict('任务押金不足，请联系商家补充');
    const fee = r2((gross * t.fee_pct) / 100);
    const net = r2(gross - fee);
    const cash = r2((net * t.cash_pct) / (t.cash_pct + t.clear_pct || 1));
    const clearCash = r2(net - cash);
    const mult = t.boost ? laborMultiplier(u.credit_score) : 1;
    const clearFace = r2(clearCash * mult);
    run('UPDATE tasks SET deposit_left = deposit_left - ?, done = done + 1, updated_at = ? WHERE id = ?', gross, nowIso(), t.id);
    run('UPDATE users SET wallet_frozen = MAX(0, wallet_frozen - ?) WHERE id = ?', gross, t.publisher_id);
    if (cash > 0) walletChange(u.id, cash, 'task_income', `微劳动收入 · ${t.title}`, o.order_no);
    let batchId = null;
    if (clearCash > 0) batchId = issueDp(u.id, 'labor', clearFace, clearCash, 'task_order', o.id, `微劳动 · ${t.title}`);
    postLedger('task_settle', o.order_no, [
      [`任务押金托管·${t.task_no}`, 'D', gross],
      ['平台服务费收入', 'C', fee],
      [`用户钱包·U${u.id}`, 'C', cash],
      [`债务积分现金备付金·U${u.id}`, 'C', clearCash],
    ]);
    const at = nowIso();
    const cur = one('SELECT * FROM task_orders WHERE id = ?', o.id);
    run('UPDATE task_orders SET status = 80, gross = ?, fee = ?, cash_amount = ?, clear_cash = ?, clear_amount = ?, multiplier = ?, settled_at = ?, history_json = ?, updated_at = ? WHERE id = ?', gross, fee, cash, clearCash, clearFace, mult, at,
      pushHist(cur, 80, `已结算：现金 ¥${cash.toFixed(2)} 到钱包 + 清偿金 ¥${clearFace.toFixed(2)}${mult > 1 ? `（信用加成 ×${mult}）` : ''}`, 'SYSTEM'), at, o.id);
    // 劳动等级：每完成 5 单升 1 级（最高 5）
    const done = one('SELECT COUNT(*) n FROM task_orders WHERE user_id = ? AND status = 80', u.id).n;
    run('UPDATE users SET labor_level = ?, credit_score = credit_score + 1 WHERE id = ?', Math.min(5, 1 + Math.floor(done / 5)), u.id);
    notify(u.id, '任务报酬已到账', `「${t.title}」结算完成：¥${cash.toFixed(2)} 已进钱包（可提现），清偿金 ¥${clearFace.toFixed(2)} 已到账。`);
    // 任务全部完成后退回剩余押金
    const left = one(`SELECT COUNT(*) n FROM task_orders WHERE task_id = ? AND status IN (${ACTIVE.join(',')})`, t.id).n;
    const t2 = one('SELECT * FROM tasks WHERE id = ?', t.id);
    if (t2.done >= t2.quota && left === 0) {
      run('UPDATE tasks SET status = 4 WHERE id = ?', t.id);
      refundDeposit(t2, '任务完成');
    }
    void batchId;
    return orderView(one('SELECT * FROM task_orders WHERE id = ?', o.id));
  });
}

/** 定时任务：交付超时、验收超时自动通过、截止任务退押金 */
export function runLaborJobs() {
  const now = nowIso();
  let timeout = 0;
  let autoPass = 0;
  let closed = 0;
  for (const o of all('SELECT * FROM task_orders WHERE status IN (20,45) AND due_at < ?', now)) {
    tx(() => {
      run('UPDATE task_orders SET status = 31, history_json = ?, updated_at = ? WHERE id = ?', pushHist(o, 31, '超过交付时限，系统关闭', 'SYSTEM'), now, o.id);
      releaseSlot(one('SELECT * FROM tasks WHERE id = ?', o.task_id), o);
    });
    timeout++;
  }
  for (const o of all('SELECT * FROM task_orders WHERE status = 50 AND review_due_at < ?', now)) {
    try {
      tx(() => {
        run('UPDATE task_orders SET status = 60, review_note = ?, history_json = ? WHERE id = ?', '商家超时未验收，自动通过', pushHist(o, 60, '商家超时未验收，系统自动通过', 'SYSTEM'), o.id);
        settleOrder(o.id);
      });
      autoPass++;
    } catch (e) { console.error('[labor auto-pass]', e.message); }
  }
  for (const t of all('SELECT * FROM tasks WHERE status IN (2,3) AND deadline_at < ?', now)) {
    if (one(`SELECT id FROM task_orders WHERE task_id = ? AND status IN (${ACTIVE.join(',')}) LIMIT 1`, t.id)) continue;
    tx(() => {
      run('UPDATE tasks SET status = 4 WHERE id = ?', t.id);
      refundDeposit(t, '任务到期');
    });
    closed++;
  }
  return { timeout, autoPass, closed };
}

export function laborSummary(uid) {
  const s = one(`SELECT COUNT(*) total, SUM(status = 80) done, SUM(status IN (${ACTIVE.join(',')})) active, COALESCE(SUM(cash_amount),0) cash, COALESCE(SUM(clear_amount),0) clear, COALESCE(AVG(rating),0) rating FROM task_orders WHERE user_id = ?`, uid);
  const u = one('SELECT labor_level, wallet_balance FROM users WHERE id = ?', uid);
  return { total: s.total, done: s.done || 0, active: s.active || 0, cash: r2(s.cash), clear: r2(s.clear), rating: r2(s.rating), level: u.labor_level, wallet: u.wallet_balance, kyc: kycLevel(uid) };
}

void bizNo;
