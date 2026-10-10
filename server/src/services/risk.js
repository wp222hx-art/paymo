/**
 * 风控：规则可在后台启停/调阈值；命中生成风险案件，按 action 决定放行 / 人工复核 / 拦截。
 */
import { all, nowIso, one, run } from '../db.js';

export const RULES = [
  ['WD-LARGE-001', '单笔大额提现', 'withdraw', '单笔提现金额超过阈值', 60, 'review', 2000],
  ['WD-FREQ-002', '24 小时高频提现', 'withdraw', '24 小时内提现次数超过阈值', 55, 'review', 3],
  ['WD-NEWBIND-003', '新绑卡即提现', 'withdraw', '银行卡绑定不足 24 小时即申请提现', 50, 'review', 24],
  ['WD-RATIO-004', '提现占收入比异常', 'withdraw', '累计提现超过累计收入的阈值比例（含充值）', 80, 'block', 1.0],
  ['TSK-LOWAI-005', '交付质量极低', 'task', 'AI 初审分低于阈值，疑似刷单/敷衍交付', 45, 'review', 40],
  ['TSK-SPEED-006', '接单即交付', 'task', '接单后极短时间内提交（分钟）', 40, 'review', 3],
  ['CNT-INDUCE-007', '引流与违规话术', 'content', '含联系方式引流、征信修复、内部渠道等话术', 96, 'block', null],
  ['CNT-SENSE-008', '敏感话题人工复核', 'content', '涉及催收、法律纠纷等，转人工复核', 50, 'review', null],
];

export function seedRisk() {
  for (const [code, name, scene, desc, score, action, th] of RULES) {
    run('INSERT OR IGNORE INTO risk_rules (code, name, scene, description, score, action, threshold) VALUES (?,?,?,?,?,?,?)', code, name, scene, desc, score, action, th);
  }
}

const rule = (code) => one('SELECT * FROM risk_rules WHERE code = ? AND enabled = 1', code);

function hit(r, userId, ctx, detail) {
  run('UPDATE risk_rules SET hits = hits + 1 WHERE code = ?', r.code);
  const x = run('INSERT INTO risk_cases (user_id, rule_code, scene, ref_type, ref_id, score, detail, status, created_at) VALUES (?,?,?,?,?,?,?,0,?)', userId, r.code, r.scene, ctx.ref_type || null, ctx.ref_id || null, r.score, detail, nowIso());
  return { code: r.code, name: r.name, score: r.score, action: r.action, case_id: Number(x.lastInsertRowid), detail };
}

/** 返回 { action: pass|review|block, score, hits[] } */
export function evalRisk(scene, userId, ctx = {}) {
  const hits = [];
  if (scene === 'withdraw') {
    let r = rule('WD-LARGE-001');
    if (r && ctx.amount > (r.threshold ?? 2000)) hits.push(hit(r, userId, ctx, `单笔提现 ¥${ctx.amount}`));
    r = rule('WD-FREQ-002');
    if (r) {
      const n = one("SELECT COUNT(*) n FROM withdrawals WHERE user_id = ? AND created_at > ?", userId, new Date(Date.now() - 86400_000).toISOString()).n;
      if (n >= (r.threshold ?? 3)) hits.push(hit(r, userId, ctx, `24 小时内已提现 ${n} 次`));
    }
    r = rule('WD-NEWBIND-003');
    const k = one('SELECT updated_at FROM kyc WHERE user_id = ? AND level >= 4', userId);
    if (r && k && Date.now() - new Date(k.updated_at).getTime() < (r.threshold ?? 24) * 3600_000 && ctx.amount > 500) hits.push(hit(r, userId, ctx, '新绑卡 24 小时内申请提现'));
    r = rule('WD-RATIO-004');
    if (r) {
      const income = one("SELECT COALESCE(SUM(amount),0) s FROM wallet_txs WHERE user_id = ? AND amount > 0 AND type NOT IN ('withdraw_refund')", userId).s;
      const out = one('SELECT COALESCE(SUM(amount),0) s FROM withdrawals WHERE user_id = ? AND status IN (10,20,30)', userId).s + (ctx.amount || 0);
      if (income > 0 && out > income * (r.threshold ?? 1)) hits.push(hit(r, userId, ctx, `提现 ¥${out} 超过入账 ¥${income}`));
    }
  } else if (scene === 'task') {
    let r = rule('TSK-LOWAI-005');
    if (r && ctx.ai_score != null && ctx.ai_score < (r.threshold ?? 40)) hits.push(hit(r, userId, ctx, `AI 初审 ${ctx.ai_score} 分：${(ctx.reasons || []).join('；')}`));
    r = rule('TSK-SPEED-006');
    if (r && ctx.minutes != null && ctx.minutes < (r.threshold ?? 3)) hits.push(hit(r, userId, ctx, `接单 ${ctx.minutes} 分钟即提交`));
  } else if (scene === 'content') {
    let r = rule('CNT-INDUCE-007');
    if (r && /加微信|加V|vx|微信号|征信修复|内部渠道|消除逾期|包下款/i.test(ctx.text || '')) hits.push(hit(r, userId, ctx, '命中引流/违规话术'));
    r = rule('CNT-SENSE-008');
    if (r && /催收|起诉|律师函|失信/.test(ctx.text || '')) hits.push(hit(r, userId, ctx, '涉及敏感话题'));
  }
  const action = hits.some((h) => h.action === 'block') ? 'block' : hits.some((h) => h.action === 'review') ? 'review' : 'pass';
  return { action, score: Math.max(0, ...hits.map((h) => h.score)), hits };
}

export const riskCases = (status) => all(`SELECT c.*, u.nickname, r.name rule_name, r.action FROM risk_cases c LEFT JOIN users u ON u.id = c.user_id LEFT JOIN risk_rules r ON r.code = c.rule_code ${status != null ? 'WHERE c.status = ?' : ''} ORDER BY c.id DESC LIMIT 300`, ...(status != null ? [status] : []));
