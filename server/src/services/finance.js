import { all, bizNo, getSetting, nowIso, one, r2, run, tx } from '../db.js';
import { E } from '../errors.js';
import { issueCertificate, letter } from './bank.js';

// ───────────────────────── 复式记账 ─────────────────────────

/** lines: [[账户, 'D'|'C', 金额]]，借贷必须平衡，零金额分录自动忽略 */
export function postLedger(bizType, bizRef, lines) {
  const valid = lines.filter((l) => Math.abs(l[2]) > 0.0001);
  let d = 0;
  let c = 0;
  for (const [, dir, amt] of valid) dir === 'D' ? (d += amt) : (c += amt);
  if (Math.abs(r2(d) - r2(c)) > 0.005) throw new Error(`借贷不平衡 D=${d} C=${c} (${bizType}/${bizRef})`);
  const txNo = bizNo('TX');
  const at = nowIso();
  for (const [acc, dir, amt] of valid) {
    run('INSERT INTO ledger (tx_no, account, direction, amount, biz_type, biz_ref, created_at) VALUES (?,?,?,?,?,?,?)', txNo, acc, dir, r2(amt), bizType, bizRef, at);
  }
  return txNo;
}

// ───────────────────────── 钱包 ─────────────────────────

export function walletChange(userId, amount, type, title, ref) {
  const u = one('SELECT wallet_balance FROM users WHERE id = ?', userId);
  const next = r2(u.wallet_balance + amount);
  if (next < -0.001) throw E.balance(`钱包余额不足：需 ¥${Math.abs(amount).toFixed(2)}，当前 ¥${u.wallet_balance.toFixed(2)}`);
  run('UPDATE users SET wallet_balance = ? WHERE id = ?', next, userId);
  run('INSERT INTO wallet_txs (user_id, type, title, amount, balance_after, ref, created_at) VALUES (?,?,?,?,?,?,?)', userId, type, title, r2(amount), next, ref ?? null, nowIso());
  return next;
}

export function notify(userId, title, body) {
  run('INSERT INTO notifications (user_id, title, body, created_at) VALUES (?,?,?,?)', userId, title, body, nowIso());
}

// ───────────────────────── 平债倍率引擎（沿用 App 模型） ─────────────────────────

/**
 * 最终倍率 = min(品类基础倍率 + 信用分加成, 全局上限)
 * 生效规则 = 灰度(1) + 生产(2)；品类无规则时用 default_multiplier
 */
export function quoteMultiplier(categoryId, creditScore) {
  const live = all('SELECT * FROM offset_rules WHERE status IN (1,2) ORDER BY status DESC, id DESC');
  // 小类优先匹配自身规则，其次匹配所属大类规则
  const parent = one('SELECT parent_id FROM categories WHERE id = ?', categoryId)?.parent_id;
  const cat = live.find((r) => r.rule_type === 'category' && r.category_id === categoryId) || (parent ? live.find((r) => r.rule_type === 'category' && r.category_id === parent) : undefined);
  const tier = live.find((r) => r.rule_type === 'credit_tier' && creditScore >= (r.credit_min ?? 0) && creditScore <= (r.credit_max ?? 9999));
  const cap = live.find((r) => r.rule_type === 'global_cap');
  const base = cat ? cat.value : getSetting('default_multiplier', 1);
  const bonus = tier ? tier.value : 0;
  const capV = cap ? cap.value : 99;
  const final = Math.min(base + bonus, capV);
  const rules = [cat?.code, tier?.code, cap && base + bonus > capV ? cap.code : null].filter(Boolean);
  const ruleIds = [cat?.id, tier?.id, cap && base + bonus > capV ? cap.id : null].filter(Boolean);
  const explain = `品类基础 ×${base.toFixed(1)} + 信用加成 ×${bonus.toFixed(1)}${final < base + bonus ? ` → 触及上限 ×${capV.toFixed(1)}` : ''}`;
  return { base, bonus, cap: capV, multiplier: r2(final), rules, ruleIds, explain };
}

/** 单个商品行的佣金与积分 */
export function quoteLine(product, qty, creditScore) {
  const subtotal = r2(product.price * qty);
  const commission = r2((subtotal * product.commission_rate) / 100);
  const q = quoteMultiplier(product.category_id, creditScore);
  const dp = r2(commission * q.multiplier);
  return { subtotal, commission, multiplier: q.multiplier, dp, quote: q };
}

// ───────────────────────── 债务积分 ─────────────────────────

export function issueDp(userId, source, face, cash, refType, refId, title) {
  const r = run('INSERT INTO dp_batches (user_id, source, face_value, cash_backed, ref_type, ref_id, title, created_at) VALUES (?,?,?,?,?,?,?,?)', userId, source, r2(face), r2(cash), refType, refId, title, nowIso());
  return Number(r.lastInsertRowid);
}

export function dpSummary(userId) {
  const rows = all('SELECT * FROM dp_batches WHERE user_id = ?', userId);
  let available = 0;
  let cash = 0;
  let issued = 0;
  let consumed = 0;
  for (const b of rows) {
    const rem = r2(b.face_value - b.consumed);
    issued += b.face_value;
    consumed += b.consumed;
    available += rem;
    cash += b.face_value > 0 ? (b.cash_backed * rem) / b.face_value : 0;
  }
  const pending = one('SELECT COALESCE(SUM(dp_amount),0) dp, COALESCE(SUM(commission),0) c FROM commissions WHERE user_id = ? AND status IN (0,1)', userId);
  return {
    available: r2(available),
    cash_backed: r2(cash),
    backing_ratio: available > 0 ? r2(cash / available) : 0,
    issued: r2(issued),
    consumed: r2(consumed),
    pending_dp: r2(pending.dp),
    pending_commission: r2(pending.c),
  };
}

// ───────────────────────── 佣金结算 ─────────────────────────

/** 确认收货后佣金进入冷静期（待结算），到期自动入账 */
export function commissionToPending(orderId) {
  const days = getSetting('commission_settle_days', 7);
  const at = new Date(Date.now() + days * 86400_000).toISOString();
  run('UPDATE commissions SET status = 1, settle_at = ? WHERE order_id = ? AND status = 0', at, orderId);
  if (days <= 0) settleCommission(one('SELECT id FROM commissions WHERE order_id = ?', orderId).id);
}

/** 佣金入账：发放债务积分批次 + 备付金记账 */
export function settleCommission(commissionId) {
  return tx(() => {
    const c = one('SELECT * FROM commissions WHERE id = ?', commissionId);
    if (!c) throw E.notFound('清偿金记录不存在');
    if (c.status === 2) throw E.conflict('该笔清偿金已到账');
    if (c.status !== 1) throw E.conflict('仅「保障期中」的清偿金可提前到账（需用户先确认收货）');
    const o = one('SELECT order_no FROM orders WHERE id = ?', c.order_id);
    const batchId = issueDp(c.user_id, 'consumption', c.dp_amount, c.commission, 'order', c.order_id, `购物返还 · 订单 ${o.order_no}`);
    run('UPDATE commissions SET status = 2, settled_at = ?, dp_batch_id = ? WHERE id = ?', nowIso(), batchId, c.id);
    postLedger('commission_settle', o.order_no, [
      ['平台佣金收入·待结算', 'D', c.commission],
      [`债务积分现金备付金·U${c.user_id}`, 'C', c.commission],
    ]);
    notify(c.user_id, '清偿金已到账', `订单 ${o.order_no} 返还的清偿金 ¥${c.dp_amount.toFixed(2)} 已到账，可随时用于一键清偿。`);
    return { commission_id: c.id, dp_batch_id: batchId, dp_amount: c.dp_amount };
  });
}

export function settleDueCommissions() {
  const due = all('SELECT id FROM commissions WHERE status = 1 AND settle_at <= ?', nowIso());
  let n = 0;
  for (const c of due) {
    try {
      settleCommission(c.id);
      n++;
    } catch (e) {
      console.error('[settle]', c.id, e.message);
    }
  }
  return n;
}

// ───────────────────────── 债务清算 ─────────────────────────

export const CLEAR_STATUS = { 10: '已提交', 20: '银行已受理', 30: '资金已划转', 50: '已核减', 90: '已退回' };

const pushHistory = (cl, status, note, operator) => {
  const h = JSON.parse(cl.history_json || '[]');
  h.push({ status, note, operator, at: nowIso() });
  return JSON.stringify(h);
};

/** 用户提交清算：FIFO 消耗积分批次，按批次背书比例计算真实划付现金 */
export function submitClearance(userId, caseId, points) {
  return tx(() => {
    const c = one('SELECT * FROM debt_cases WHERE id = ? AND user_id = ?', caseId, userId);
    if (!c) throw E.notFound('账单不存在');
    if (c.status === 3) throw E.conflict('该账单已偿清');
    if (one('SELECT id FROM clearances WHERE case_id = ? AND status IN (10,20,30)', caseId)) throw E.conflict('该账单已有清偿在处理中');
    const min = getSetting('min_clear_points', 10);
    const sum = dpSummary(userId);
    let pts = points == null ? sum.available : Number(points);
    if (!(pts > 0)) throw E.bad('清偿金额必须大于 0');
    if (pts > sum.available + 0.001) throw E.balance(`清偿金不足：可用 ¥${sum.available.toFixed(2)}`);
    pts = r2(Math.min(pts, c.outstanding));
    if (pts < min && pts < c.outstanding) throw E.bad(`单次清偿至少 ¥${min}`);

    let need = pts;
    let cash = 0;
    const consumed = {};
    for (const b of all('SELECT * FROM dp_batches WHERE user_id = ? AND face_value - consumed > 0.0001 ORDER BY id ASC', userId)) {
      if (need <= 0.0001) break;
      const use = r2(Math.min(need, b.face_value - b.consumed));
      cash += (b.cash_backed * use) / b.face_value;
      run('UPDATE dp_batches SET consumed = ? WHERE id = ?', r2(b.consumed + use), b.id);
      consumed[b.id] = use;
      need = r2(need - use);
    }
    cash = r2(cash);
    const no = bizNo('CL');
    const at = nowIso();
    const history = JSON.stringify([{ status: 10, note: `提交清偿 ¥${pts.toFixed(2)}（资金 ¥${cash.toFixed(2)}）`, operator: `USER:${userId}`, at }]);
    const r = run('INSERT INTO clearances (clearance_no, user_id, case_id, points, cash_remitted, reduction, consumed_json, status, history_json, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', no, userId, caseId, pts, cash, r2(pts - cash), JSON.stringify(consumed), 10, history, at, at);
    notify(userId, '清偿已提交', `已向「${c.creditor}」提交清偿 ¥${pts.toFixed(2)}，等待银行受理。`);
    return { id: Number(r.lastInsertRowid), clearance_no: no, points: pts, cash_remitted: cash, reduction: r2(pts - cash) };
  });
}

/** 后台（债权方/清算专员）处理清算单 */
export function processClearance(id, action, operator, body = {}) {
  return tx(() => {
    const cl = one('SELECT * FROM clearances WHERE id = ?', id);
    if (!cl) throw E.notFound('清偿单不存在');
    const c = one('SELECT * FROM debt_cases WHERE id = ?', cl.case_id);
    const at = nowIso();
    switch (action) {
      case 'accept': {
        if (cl.status !== 10) throw E.conflict(`状态「${CLEAR_STATUS[cl.status]}」不可受理`);
        run('UPDATE clearances SET status = 20, history_json = ?, updated_at = ? WHERE id = ?', pushHistory(cl, 20, '银行已受理，正在核对清偿金', operator), at, id);
        notify(cl.user_id, '银行已受理你的清偿', `${c.creditor} 已受理清偿单 ${cl.clearance_no}（¥${cl.points.toFixed(2)}）。`);
        break;
      }
      case 'remit': {
        if (cl.status !== 20) throw E.conflict('需先受理');
        const ref = body.bank_ref || bizNo('UNP');
        postLedger('clearance_remit', cl.clearance_no, [
          [`债务积分现金备付金·U${cl.user_id}`, 'D', cl.cash_remitted],
          [`债权方实收·${c.creditor}`, 'C', cl.cash_remitted],
        ]);
        run('UPDATE clearances SET status = 30, bank_ref = ?, history_json = ?, updated_at = ? WHERE id = ?', ref, pushHistory(cl, 30, `资金已划转至银行 ¥${cl.cash_remitted.toFixed(2)} · 流水 ${ref}`, operator), at, id);
        break;
      }
      case 'write-off': {
        if (cl.status !== 30) throw E.conflict('需先确认资金划付');
        const out = r2(Math.max(0, c.outstanding - cl.points));
        run('UPDATE debt_cases SET outstanding = ?, cleared = ?, cash_paid = cash_paid + ? WHERE id = ?', out, r2(c.cleared + cl.points), cl.cash_remitted, c.id);
        run('UPDATE clearances SET status = 50, history_json = ?, updated_at = ? WHERE id = ?', pushHistory(cl, 50, `银行已核减账单 ¥${cl.points.toFixed(2)}（资金 ¥${cl.cash_remitted.toFixed(2)} + 银行让利 ¥${cl.reduction.toFixed(2)}）`, operator), at, id);
        run('UPDATE users SET credit_score = credit_score + 3 WHERE id = ?', cl.user_id);
        if (out <= 0.005) {
          issueCertificate(c.id, operator);
        } else {
          letter(cl.user_id, c.id, c.creditor, 'partial', '清偿回执', `尊敬的客户：我行已收到您通过星光云提交的清偿 ¥${cl.points.toFixed(2)}（单号 ${cl.clearance_no}），已为您核减账单。当前剩余待清偿 ¥${out.toFixed(2)}，继续保持，离偿清越来越近。`);
          notify(cl.user_id, '清偿完成 · 账单已核减', `${c.creditor} 已核减 ¥${cl.points.toFixed(2)}，剩余 ¥${out.toFixed(2)}。信用分 +3。`);
        }
        break;
      }
      case 'reject': {
        if (![10, 20].includes(cl.status)) throw E.conflict('资金已划付，不可退回');
        const reason = String(body.reason || '资料不全').slice(0, 200);
        for (const [bid, amt] of Object.entries(JSON.parse(cl.consumed_json))) {
          run('UPDATE dp_batches SET consumed = MAX(0, consumed - ?) WHERE id = ?', amt, Number(bid));
        }
        run('UPDATE clearances SET status = 90, reject_reason = ?, history_json = ?, updated_at = ? WHERE id = ?', reason, pushHistory(cl, 90, `退回：${reason}，清偿金已返还`, operator), at, id);
        notify(cl.user_id, '清偿被退回', `${cl.clearance_no} 被退回：${reason}。¥${cl.points.toFixed(2)} 清偿金已返还。`);
        break;
      }
      default:
        throw E.bad('未知操作');
    }
    return one('SELECT * FROM clearances WHERE id = ?', id);
  });
}
