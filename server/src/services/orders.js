import { all, bizNo, getSetting, nowIso, one, r2, run, tx } from '../db.js';
import { E } from '../errors.js';
import { commissionToPending, notify, postLedger, quoteLine, walletChange } from './finance.js';

export const ORDER_STATUS = { 10: '待支付', 20: '待发货', 30: '已发货', 40: '已完成', 50: '已取消', 60: '退款中', 70: '已退款' };
export const COMMISSION_STATUS = { 0: '待收货', 1: '保障期中', 2: '已到账', 9: '已失效' };
const CHANNELS = { wallet: '钱包余额', wechat: '微信支付', alipay: '支付宝' };

/** 计算一组商品的金额、运费、佣金、积分（预览与下单共用） */
export function priceItems(user, items) {
  if (!Array.isArray(items) || items.length === 0) throw E.bad('请选择商品');
  if (items.length > 50) throw E.bad('单次最多 50 种商品');
  const lines = [];
  for (const it of items) {
    const qty = Number(it.qty);
    if (!Number.isInteger(qty) || qty < 1 || qty > 99) throw E.bad('购买数量需为 1~99');
    const p = one('SELECT p.*, c.status cstatus FROM products p JOIN categories c ON c.id = p.category_id WHERE p.id = ?', Number(it.product_id));
    if (!p) throw E.notFound(`商品 ${it.product_id} 不存在`);
    if (p.status !== 1 || p.cstatus !== 1) throw E.conflict(`「${p.name}」已下架`);
    if (p.stock < qty) throw E.stock(`「${p.name}」库存不足，仅剩 ${p.stock} 件`);
    const q = quoteLine(p, qty, user.credit_score);
    lines.push({ product: p, qty, ...q });
  }
  const goods = r2(lines.reduce((a, l) => a + l.subtotal, 0));
  const threshold = getSetting('free_freight_threshold', 99);
  const freight = goods >= threshold ? 0 : getSetting('freight_fee', 8);
  const commission = r2(lines.reduce((a, l) => a + l.commission, 0));
  const dp = r2(lines.reduce((a, l) => a + l.dp, 0));
  return { lines, goods, freight: r2(freight), pay: r2(goods + freight), commission, dp, free_freight_threshold: threshold };
}

export function previewView(p) {
  return {
    items: p.lines.map((l) => ({
      product_id: l.product.id, name: l.product.name, image: l.product.image, emoji: l.product.emoji, price: l.product.price, qty: l.qty,
      subtotal: l.subtotal, commission_rate: l.product.commission_rate, commission: l.commission, multiplier: l.multiplier, dp_amount: l.dp, explain: l.quote.explain, rules: l.quote.rules,
    })),
    goods_amount: p.goods, freight_amount: p.freight, pay_amount: p.pay, commission_amount: p.commission, dp_amount: p.dp, free_freight_threshold: p.free_freight_threshold,
  };
}

export function createOrder(user, { items, address_id, remark, from_cart }) {
  return tx(() => {
    const p = priceItems(user, items);
    let addr = null;
    if (address_id) {
      addr = one('SELECT name, phone, region, detail FROM addresses WHERE id = ? AND user_id = ?', Number(address_id), user.id);
      if (!addr) throw E.notFound('收货地址不存在');
    }
    const no = bizNo('SO');
    const at = nowIso();
    const expire = new Date(Date.now() + getSetting('order_expire_minutes', 30) * 60_000).toISOString();
    const r = run(
      'INSERT INTO orders (order_no, user_id, status, goods_amount, freight_amount, pay_amount, commission_amount, dp_amount, address_json, remark, expire_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      no, user.id, 10, p.goods, p.freight, p.pay, p.commission, p.dp, addr ? JSON.stringify(addr) : null, remark ? String(remark).slice(0, 200) : null, expire, at, at,
    );
    const orderId = Number(r.lastInsertRowid);
    for (const l of p.lines) {
      // 乐观扣库存：条件更新失败即视为并发超卖
      const u = run('UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?', l.qty, l.product.id, l.qty);
      if (u.changes === 0) throw E.stock(`「${l.product.name}」库存不足`);
      run(
        'INSERT INTO order_items (order_id, product_id, category_id, name, image, emoji, price, qty, subtotal, commission_rate, commission, multiplier, dp_amount, rule_snapshot) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        orderId, l.product.id, l.product.category_id, l.product.name, l.product.image, l.product.emoji, l.product.price, l.qty, l.subtotal, l.product.commission_rate, l.commission, l.multiplier, l.dp, `${l.quote.explain} · ${l.quote.rules.join(',')}`,
      );
      for (const rid of l.quote.ruleIds) run('UPDATE offset_rules SET hit_count = hit_count + 1 WHERE id = ?', rid);
    }
    if (from_cart) {
      for (const l of p.lines) run('DELETE FROM cart_items WHERE user_id = ? AND product_id = ?', user.id, l.product.id);
    }
    return getOrder(orderId);
  });
}

export function getOrder(id, userId) {
  const o = userId ? one('SELECT * FROM orders WHERE id = ? AND user_id = ?', id, userId) : one('SELECT * FROM orders WHERE id = ?', id);
  if (!o) throw E.notFound('订单不存在');
  return orderView(o, true);
}

export function orderView(o, detail = false) {
  const items = all('SELECT * FROM order_items WHERE order_id = ?', o.id);
  const c = one('SELECT status, settle_at, settled_at FROM commissions WHERE order_id = ?', o.id);
  const v = {
    ...o,
    status_label: ORDER_STATUS[o.status],
    address: o.address_json ? JSON.parse(o.address_json) : null,
    items,
    commission_status: c ? c.status : null,
    commission_status_label: c ? COMMISSION_STATUS[c.status] : '未产生',
    commission_settle_at: c?.settle_at ?? null,
  };
  delete v.address_json;
  if (detail) {
    v.payments = all('SELECT pay_no, channel, amount, status, trade_no, created_at, paid_at FROM payments WHERE order_id = ?', o.id);
    v.ledger = all('SELECT * FROM ledger WHERE biz_ref = ? ORDER BY id', o.order_no);
  }
  return v;
}

/** 发起支付：wallet 直接扣款成功；wechat/alipay 生成待支付流水，由模拟收银台回调 */
export function payOrder(user, orderId, channel) {
  if (!CHANNELS[channel]) throw E.bad('不支持的支付方式');
  return tx(() => {
    const o = one('SELECT * FROM orders WHERE id = ? AND user_id = ?', orderId, user.id);
    if (!o) throw E.notFound('订单不存在');
    if (o.status !== 10) throw E.conflict(`订单状态「${ORDER_STATUS[o.status]}」不可支付`);
    if (o.expire_at < nowIso()) {
      cancelOrder(o.id, '超时未支付，系统自动取消');
      throw E.conflict('订单已超时关闭');
    }
    run('UPDATE payments SET status = 2 WHERE order_id = ? AND status = 0', o.id);
    const payNo = bizNo('PAY');
    run('INSERT INTO payments (pay_no, order_id, user_id, channel, amount, status, created_at) VALUES (?,?,?,?,?,?,?)', payNo, o.id, user.id, channel, o.pay_amount, 0, nowIso());
    if (channel === 'wallet') {
      markPaid(payNo, `WALLET${Date.now()}`);
      return { pay_no: payNo, channel, paid: true, order: getOrder(o.id) };
    }
    return { pay_no: payNo, channel, paid: false, amount: o.pay_amount, cashier: `/api/pay/mock/${payNo}`, tip: '模拟收银台：调用 POST /api/pay/mock/:pay_no/confirm 完成支付' };
  });
}

/** 支付成功回调（钱包 / 第三方异步通知共用，幂等） */
export function markPaid(payNo, tradeNo) {
  return tx(() => {
    const pay = one('SELECT * FROM payments WHERE pay_no = ?', payNo);
    if (!pay) throw E.notFound('支付单不存在');
    if (pay.status === 1) return { idempotent: true };
    if (pay.status !== 0) throw E.conflict('支付单已关闭');
    const o = one('SELECT * FROM orders WHERE id = ?', pay.order_id);
    if (o.status !== 10) throw E.conflict(`订单状态「${ORDER_STATUS[o.status]}」不可支付`);
    if (pay.channel === 'wallet') walletChange(o.user_id, -o.pay_amount, 'shop_pay', `商城订单 ${o.order_no}`, o.order_no);
    const at = nowIso();
    run('UPDATE payments SET status = 1, trade_no = ?, paid_at = ? WHERE id = ?', tradeNo, at, pay.id);
    run('UPDATE orders SET status = 20, pay_channel = ?, paid_at = ?, updated_at = ? WHERE id = ?', pay.channel, at, at, o.id);
    for (const it of all('SELECT product_id, qty FROM order_items WHERE order_id = ?', o.id)) run('UPDATE products SET sales = sales + ? WHERE id = ?', it.qty, it.product_id);
    postLedger('shop_pay', o.order_no, [
      [pay.channel === 'wallet' ? `用户钱包·U${o.user_id}` : `支付通道待清算·${CHANNELS[pay.channel]}`, 'D', o.pay_amount],
      ['自营货款·应付', 'C', r2(o.pay_amount - o.commission_amount)],
      ['平台佣金收入·待结算', 'C', o.commission_amount],
    ]);
    run('INSERT INTO commissions (user_id, order_id, commission, dp_amount, status, created_at) VALUES (?,?,?,?,0,?)', o.user_id, o.id, o.commission_amount, o.dp_amount, at);
    notify(o.user_id, '支付成功', `订单 ${o.order_no} 已支付 ¥${o.pay_amount.toFixed(2)}，已为你预留清偿金 ¥${o.dp_amount.toFixed(2)}，确认收货后进入保障期。`);
    return { idempotent: false };
  });
}

export function cancelOrder(orderId, reason, userId) {
  return tx(() => {
    const o = userId ? one('SELECT * FROM orders WHERE id = ? AND user_id = ?', orderId, userId) : one('SELECT * FROM orders WHERE id = ?', orderId);
    if (!o) throw E.notFound('订单不存在');
    if (o.status !== 10) throw E.conflict('仅待支付订单可取消，已支付请申请退款');
    restoreStock(o.id);
    const at = nowIso();
    run('UPDATE payments SET status = 2 WHERE order_id = ? AND status = 0', o.id);
    run('UPDATE orders SET status = 50, cancelled_at = ?, cancel_reason = ?, updated_at = ? WHERE id = ?', at, reason || '用户取消', at, o.id);
    return getOrder(o.id);
  });
}

function restoreStock(orderId) {
  for (const it of all('SELECT product_id, qty FROM order_items WHERE order_id = ?', orderId)) run('UPDATE products SET stock = stock + ? WHERE id = ?', it.qty, it.product_id);
}

export function shipOrder(orderId, company, expressNo) {
  return tx(() => {
    const o = one('SELECT * FROM orders WHERE id = ?', orderId);
    if (!o) throw E.notFound('订单不存在');
    if (o.status !== 20) throw E.conflict(`订单状态「${ORDER_STATUS[o.status]}」不可发货`);
    const at = nowIso();
    run('UPDATE orders SET status = 30, shipped_at = ?, express_company = ?, express_no = ?, updated_at = ? WHERE id = ?', at, company || '虚拟商品/到店核销', expressNo || '-', at, o.id);
    notify(o.user_id, '订单已发货', `订单 ${o.order_no} 已发货（${company || '虚拟商品'} ${expressNo || ''}），收到后记得确认收货，清偿金才会开始计时到账。`);
    return getOrder(o.id);
  });
}

export function confirmReceipt(orderId, userId, auto = false) {
  return tx(() => {
    const o = userId ? one('SELECT * FROM orders WHERE id = ? AND user_id = ?', orderId, userId) : one('SELECT * FROM orders WHERE id = ?', orderId);
    if (!o) throw E.notFound('订单不存在');
    if (o.status !== 30) throw E.conflict('仅已发货订单可确认收货');
    const at = nowIso();
    run('UPDATE orders SET status = 40, completed_at = ?, updated_at = ? WHERE id = ?', at, at, o.id);
    commissionToPending(o.id);
    const days = getSetting('commission_settle_days', 7);
    notify(o.user_id, auto ? '订单已自动确认收货' : '已确认收货', `订单 ${o.order_no} 已完成，清偿金 ¥${o.dp_amount.toFixed(2)} 进入 ${days} 天售后保障期，到期自动到账。`);
    return getOrder(o.id);
  });
}

export function applyRefund(orderId, userId, reason) {
  return tx(() => {
    const o = one('SELECT * FROM orders WHERE id = ? AND user_id = ?', orderId, userId);
    if (!o) throw E.notFound('订单不存在');
    if (![20, 30, 40].includes(o.status)) throw E.conflict(`订单状态「${ORDER_STATUS[o.status]}」不可退款`);
    const c = one('SELECT status FROM commissions WHERE order_id = ?', o.id);
    if (c?.status === 2) throw E.conflict('已过售后保障期（清偿金已到账），不可退款');
    run('UPDATE orders SET pre_refund_status = status, status = 60, refund_reason = ?, updated_at = ? WHERE id = ?', String(reason || '不想要了').slice(0, 200), nowIso(), o.id);
    return getOrder(o.id);
  });
}

export function reviewRefund(orderId, approve, rejectReason) {
  return tx(() => {
    const o = one('SELECT * FROM orders WHERE id = ?', orderId);
    if (!o) throw E.notFound('订单不存在');
    if (o.status !== 60) throw E.conflict('订单不在退款中');
    const at = nowIso();
    if (!approve) {
      run('UPDATE orders SET status = pre_refund_status, refund_reject_reason = ?, updated_at = ? WHERE id = ?', rejectReason || '不符合退款条件', at, o.id);
      notify(o.user_id, '退款申请被驳回', `订单 ${o.order_no}：${rejectReason || '不符合退款条件'}`);
      return getOrder(o.id);
    }
    const pay = one('SELECT * FROM payments WHERE order_id = ? AND status = 1', o.id);
    if (pay.channel === 'wallet') walletChange(o.user_id, o.pay_amount, 'shop_refund', `订单退款 ${o.order_no}`, o.order_no);
    postLedger('shop_refund', o.order_no, [
      ['自营货款·应付', 'D', r2(o.pay_amount - o.commission_amount)],
      ['平台佣金收入·待结算', 'D', o.commission_amount],
      [pay.channel === 'wallet' ? `用户钱包·U${o.user_id}` : `支付通道待清算·${CHANNELS[pay.channel]}`, 'C', o.pay_amount],
    ]);
    run('UPDATE payments SET status = 3 WHERE id = ?', pay.id);
    run('UPDATE commissions SET status = 9 WHERE order_id = ?', o.id);
    restoreStock(o.id);
    for (const it of all('SELECT product_id, qty FROM order_items WHERE order_id = ?', o.id)) run('UPDATE products SET sales = MAX(0, sales - ?) WHERE id = ?', it.qty, it.product_id);
    run('UPDATE orders SET status = 70, refunded_at = ?, updated_at = ? WHERE id = ?', at, at, o.id);
    notify(o.user_id, '退款成功', `订单 ${o.order_no} 已退款 ¥${o.pay_amount.toFixed(2)}（原路返回），本单清偿金不再返还。`);
    return getOrder(o.id);
  });
}

/** 定时任务：超时关单 + 发货后自动确认收货 */
export function runOrderJobs() {
  let cancelled = 0;
  let confirmed = 0;
  for (const o of all('SELECT id FROM orders WHERE status = 10 AND expire_at < ?', nowIso())) {
    try { cancelOrder(o.id, '超时未支付，系统自动取消'); cancelled++; } catch (e) { console.error('[job cancel]', e.message); }
  }
  const days = getSetting('auto_confirm_days', 10);
  const before = new Date(Date.now() - days * 86400_000).toISOString();
  for (const o of all('SELECT id FROM orders WHERE status = 30 AND shipped_at < ?', before)) {
    try { confirmReceipt(o.id, null, true); confirmed++; } catch (e) { console.error('[job confirm]', e.message); }
  }
  return { cancelled, confirmed };
}
