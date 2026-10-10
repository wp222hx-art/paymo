import { Router } from 'express';
import { all, getSetting, nowIso, one, r2, run } from '../db.js';
import { requireUser, sign } from '../auth.js';
import { E, h, num, str } from '../errors.js';
import { dpSummary, quoteLine, submitClearance, CLEAR_STATUS } from '../services/finance.js';
import { BANKS, importBills, queryBills } from '../services/bank.js';
import { GUIDES } from '../guides.js';
import { applyRefund, cancelOrder, confirmReceipt, createOrder, getOrder, orderView, payOrder, previewView, priceItems, COMMISSION_STATUS } from '../services/orders.js';

export const DEMO_MODE = process.env.DEMO_MODE !== '0';
const SMS_CODE = process.env.DEMO_SMS_CODE || '123456';

const r = Router();

// ───────── 认证 ─────────
const tokenFor = (u) => ({ token: sign({ typ: 'user', uid: u.id }), user: userView(u) });
const userView = (u) => ({ id: u.id, ext_id: u.ext_id, role: u.role, org_name: u.org_name, bank_code: u.bank_code, wallet_frozen: u.wallet_frozen, labor_level: u.labor_level, mobile: u.mobile.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2'), nickname: u.nickname, credit_score: u.credit_score, wallet_balance: u.wallet_balance });

/** 手机号 + 短信验证码登录（未接短信网关：演示验证码由 DEMO_SMS_CODE 配置）；新手机号自动注册 */
r.post('/auth/sms-login', h((req) => {
  const mobile = str(req.body.mobile, 'mobile');
  if (!/^1\d{10}$/.test(mobile)) throw E.bad('手机号格式不正确');
  if (String(req.body.code) !== SMS_CODE) throw E.bad('验证码错误');
  let u = one('SELECT * FROM users WHERE mobile = ?', mobile);
  if (!u) {
    run('INSERT INTO users (mobile, nickname, created_at) VALUES (?,?,?)', mobile, `用户${mobile.slice(-4)}`, nowIso());
    u = one('SELECT * FROM users WHERE mobile = ?', mobile);
  }
  if (u.status === 2) throw E.forbidden('账号已冻结');
  return tokenFor(u);
}));

/** App 演示身份直连（U1001…），DEMO_MODE=0 时关闭 */
r.post('/auth/demo-login', h((req) => {
  if (!DEMO_MODE) throw E.forbidden('演示登录已关闭');
  const u = one('SELECT * FROM users WHERE ext_id = ?', str(req.body.ext_id, 'ext_id'));
  if (!u) throw E.notFound('演示账号不存在');
  if (u.status === 2) throw E.forbidden('账号已冻结');
  return tokenFor(u);
}));

// ───────── 公开商品浏览 ─────────
/** 分类树：大类 → 小类 */
r.get('/categories', h(() => {
  const rows = all(`SELECT c.id, c.name, c.icon, c.image, c.slug, c.parent_id, (SELECT COUNT(*) FROM products p WHERE p.category_id = c.id AND p.status = 1) product_count FROM categories c WHERE c.status = 1 ORDER BY c.sort, c.id`);
  const tops = rows.filter((c) => !c.parent_id);
  const flat = rows.filter((c) => c.parent_id && !tops.some((t) => t.id === c.parent_id));
  return [...tops.map((t) => {
    const children = rows.filter((c) => c.parent_id === t.id);
    return { ...t, children, product_count: t.product_count + children.reduce((a, c) => a + c.product_count, 0) };
  }), ...flat.map((c) => ({ ...c, children: [] }))];
}));

/** 新手指引视频清单（每个功能环节一条） */
r.get('/guides', h(() => GUIDES));

/** 平台公开数据：合作银行、累计偿清 */
r.get('/stats', h(() => ({
  banks: BANKS,
  settled_cases: one('SELECT COUNT(*) n FROM certificates').n,
  cleared_amount: r2(one('SELECT COALESCE(SUM(cleared),0) s FROM debt_cases').s) + 12860000,
  users: one('SELECT COUNT(*) n FROM users').n + 238000,
})));

const productCols = 'p.id, p.category_id, c.name category_name, p.name, p.subtitle, p.merchant, p.image, p.emoji, p.price, p.original_price, p.commission_rate, p.stock, p.sales';

r.get('/products', h((req) => {
  const page = num(req.query.page ?? 1, 'page', { min: 1, int: true });
  const size = num(req.query.size ?? 20, 'size', { min: 1, max: 100, int: true });
  const where = ['p.status = 1', 'c.status = 1'];
  const params = [];
  if (req.query.category_id) { where.push('(p.category_id = ? OR c.parent_id = ?)'); params.push(Number(req.query.category_id), Number(req.query.category_id)); }
  if (req.query.ids) { const ids = String(req.query.ids).split(',').map(Number).filter(Boolean).slice(0, 100); where.push(`p.id IN (${ids.map(() => '?').join(',') || 'NULL'})`); params.push(...ids); }
  if (req.query.keyword) { where.push('(p.name LIKE ? OR p.merchant LIKE ?)'); params.push(`%${req.query.keyword}%`, `%${req.query.keyword}%`); }
  const order = { sales: 'p.sales DESC', price_asc: 'p.price ASC', price_desc: 'p.price DESC', commission: 'p.price * p.commission_rate DESC', rate: 'p.commission_rate DESC' }[req.query.sort] || 'p.sort, p.id';
  const w = where.join(' AND ');
  const total = one(`SELECT COUNT(*) n FROM products p JOIN categories c ON c.id = p.category_id WHERE ${w}`, ...params).n;
  const list = all(`SELECT ${productCols} FROM products p JOIN categories c ON c.id = p.category_id WHERE ${w} ORDER BY ${order} LIMIT ? OFFSET ?`, ...params, size, (page - 1) * size);
  return { list, total, page, size };
}));

r.get('/products/:id', h((req) => {
  const p = one(`SELECT ${productCols}, p.description FROM products p JOIN categories c ON c.id = p.category_id WHERE p.id = ? AND p.status = 1`, Number(req.params.id));
  if (!p) throw E.notFound('商品不存在或已下架');
  return p;
}));

// ───────── 以下需登录 ─────────
r.use(requireUser);

r.get('/me', h((req) => ({ ...userView(req.user), debt_points: dpSummary(req.user.id) })));

/** 个人化报价：佣金 × 倍率（倍率含信用加成，因人而异） */
r.post('/quote', h((req) => {
  const ids = Array.isArray(req.body.product_ids) ? req.body.product_ids.slice(0, 200) : [];
  const out = {};
  for (const id of ids) {
    const p = one('SELECT * FROM products WHERE id = ?', Number(id));
    if (!p) continue;
    const q = quoteLine(p, 1, req.user.credit_score);
    out[p.id] = { commission: q.commission, multiplier: q.multiplier, dp_amount: q.dp, explain: q.quote.explain, rules: q.quote.rules };
  }
  return out;
}));

// 购物车
const cartRows = (uid) => {
  const u = one('SELECT credit_score FROM users WHERE id = ?', uid);
  return all(`SELECT ci.id cart_item_id, ci.qty, ci.checked, ci.product_id, p.name, p.image, p.emoji, p.price, p.stock, p.status, p.commission_rate, p.category_id FROM cart_items ci JOIN products p ON p.id = ci.product_id WHERE ci.user_id = ? ORDER BY ci.id DESC`, uid).map((x) => {
    const q = quoteLine(x, x.qty, u.credit_score);
    return { ...x, available: x.status === 1 && x.stock >= x.qty, subtotal: q.subtotal, commission: q.commission, multiplier: q.multiplier, dp_amount: q.dp };
  });
};

r.get('/cart', h((req) => cartRows(req.user.id)));
r.post('/cart', h((req) => {
  const pid = num(req.body.product_id, 'product_id', { int: true });
  const qty = num(req.body.qty ?? 1, 'qty', { min: 1, max: 99, int: true });
  const p = one('SELECT id, status FROM products WHERE id = ?', pid);
  if (!p || p.status !== 1) throw E.notFound('商品不存在或已下架');
  if (one('SELECT COUNT(*) n FROM cart_items WHERE user_id = ?', req.user.id).n >= 100) throw E.bad('购物车最多 100 件商品');
  run('INSERT INTO cart_items (user_id, product_id, qty, created_at) VALUES (?,?,?,?) ON CONFLICT(user_id, product_id) DO UPDATE SET qty = MIN(99, qty + excluded.qty)', req.user.id, pid, qty, nowIso());
  return cartRows(req.user.id);
}));
r.patch('/cart/:id', h((req) => {
  const row = one('SELECT id FROM cart_items WHERE id = ? AND user_id = ?', Number(req.params.id), req.user.id);
  if (!row) throw E.notFound('购物车条目不存在');
  if (req.body.qty !== undefined) run('UPDATE cart_items SET qty = ? WHERE id = ?', num(req.body.qty, 'qty', { min: 1, max: 99, int: true }), row.id);
  if (req.body.checked !== undefined) run('UPDATE cart_items SET checked = ? WHERE id = ?', req.body.checked ? 1 : 0, row.id);
  return cartRows(req.user.id);
}));
r.delete('/cart/:id', h((req) => {
  run('DELETE FROM cart_items WHERE id = ? AND user_id = ?', Number(req.params.id), req.user.id);
  return cartRows(req.user.id);
}));

// 收货地址
r.get('/addresses', h((req) => all('SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, id DESC', req.user.id)));
r.post('/addresses', h((req) => {
  const b = req.body;
  const phone = str(b.phone, 'phone');
  if (!/^1\d{10}$/.test(phone)) throw E.bad('手机号格式不正确');
  const isDef = b.is_default || !one('SELECT id FROM addresses WHERE user_id = ?', req.user.id) ? 1 : 0;
  if (isDef) run('UPDATE addresses SET is_default = 0 WHERE user_id = ?', req.user.id);
  const x = run('INSERT INTO addresses (user_id, name, phone, region, detail, is_default, created_at) VALUES (?,?,?,?,?,?,?)', req.user.id, str(b.name, 'name', { max: 20 }), phone, str(b.region, 'region', { max: 60 }), str(b.detail, 'detail', { max: 120 }), isDef, nowIso());
  return one('SELECT * FROM addresses WHERE id = ?', Number(x.lastInsertRowid));
}));
r.delete('/addresses/:id', h((req) => {
  run('DELETE FROM addresses WHERE id = ? AND user_id = ?', Number(req.params.id), req.user.id);
  return true;
}));

// 订单
r.post('/orders/preview', h((req) => previewView(priceItems(req.user, req.body.items))));
r.post('/orders', h((req) => createOrder(req.user, req.body)));
r.get('/orders', h((req) => {
  const params = [req.user.id];
  let w = 'user_id = ?';
  if (req.query.status) { w += ' AND status = ?'; params.push(Number(req.query.status)); }
  return all(`SELECT * FROM orders WHERE ${w} ORDER BY id DESC LIMIT 100`, ...params).map((o) => orderView(o));
}));
r.get('/orders/:id', h((req) => getOrder(Number(req.params.id), req.user.id)));
r.post('/orders/:id/pay', h((req) => payOrder(req.user, Number(req.params.id), req.body.channel || 'wallet')));
r.post('/orders/:id/cancel', h((req) => cancelOrder(Number(req.params.id), req.body.reason || '用户取消', req.user.id)));
r.post('/orders/:id/confirm', h((req) => confirmReceipt(Number(req.params.id), req.user.id)));
r.post('/orders/:id/refund', h((req) => applyRefund(Number(req.params.id), req.user.id, req.body.reason)));

// 佣金
r.get('/commissions', h((req) => {
  const list = all('SELECT cm.*, o.order_no, o.pay_amount FROM commissions cm JOIN orders o ON o.id = cm.order_id WHERE cm.user_id = ? ORDER BY cm.id DESC', req.user.id).map((c) => ({ ...c, status_label: COMMISSION_STATUS[c.status] }));
  const sum = (st) => r2(list.filter((c) => st.includes(c.status)).reduce((a, c) => a + c.dp_amount, 0));
  return { summary: { estimated_dp: sum([0]), pending_dp: sum([1]), settled_dp: sum([2]), total_commission: r2(list.filter((c) => c.status !== 9).reduce((a, c) => a + c.commission, 0)), settle_days: getSetting('commission_settle_days', 7) }, list };
}));

// 债务积分 & 清算
r.get('/debt-points', h((req) => ({ summary: dpSummary(req.user.id), batches: all('SELECT * FROM dp_batches WHERE user_id = ? ORDER BY id DESC', req.user.id) })));
r.get('/debts', h((req) => all('SELECT * FROM debt_cases WHERE user_id = ? ORDER BY status, id', req.user.id).map((c) => ({ ...c, clearing: !!one('SELECT id FROM clearances WHERE case_id = ? AND status IN (10,20,30)', c.id) }))));
r.post('/debts', h((req) => {
  const amt = num(req.body.amount, 'amount', { min: 1, max: 10_000_000 });
  const x = run('INSERT INTO debt_cases (user_id, creditor, case_no, debt_type, principal, outstanding, created_at) VALUES (?,?,?,?,?,?,?)', req.user.id, str(req.body.creditor, 'creditor', { max: 60 }), str(req.body.case_no ?? `MANUAL-${Date.now()}`, 'case_no', { max: 60 }), str(req.body.debt_type ?? '其他', 'debt_type', { max: 20 }), amt, amt, nowIso());
  return one('SELECT * FROM debt_cases WHERE id = ?', Number(x.lastInsertRowid));
}));
r.post('/clearances', h((req) => submitClearance(req.user.id, num(req.body.case_id, 'case_id', { int: true }), req.body.points)));
r.get('/clearances', h((req) => all('SELECT cl.*, d.creditor, d.case_no FROM clearances cl JOIN debt_cases d ON d.id = cl.case_id WHERE cl.user_id = ? ORDER BY cl.id DESC', req.user.id).map((c) => ({ ...c, status_label: CLEAR_STATUS[c.status], history: JSON.parse(c.history_json) }))));

// 银行：手机号查询 → 短信验证 → 授权导入；回函；偿清证明
const bankSessions = new Map(); // userId → {mobile, at}
r.post('/bank/sms', h((req) => {
  const mobile = str(req.body.mobile, 'mobile');
  if (!/^1\d{10}$/.test(mobile)) throw E.bad('请输入正确的 11 位手机号');
  return { sent: true, ttl: 60, hint: DEMO_MODE ? `演示环境验证码 ${SMS_CODE}` : undefined };
}));
r.post('/bank/query', h((req) => {
  const mobile = str(req.body.mobile, 'mobile');
  if (String(req.body.code) !== SMS_CODE) throw E.bad('验证码错误');
  if (req.body.consent !== true) throw E.bad('请先阅读并同意《银行账单查询授权书》');
  bankSessions.set(req.user.id, { mobile, at: Date.now() });
  return queryBills(mobile);
}));
r.post('/bank/import', h((req) => {
  const s = bankSessions.get(req.user.id);
  if (!s || Date.now() - s.at > 15 * 60_000) throw E.forbidden('查询授权已过期，请重新验证手机号');
  return importBills(req.user.id, s.mobile, req.body.account_ids);
}));
r.get('/bank/letters', h((req) => all('SELECT * FROM bank_letters WHERE user_id = ? ORDER BY id DESC', req.user.id)));
r.post('/bank/letters/:id/read', h((req) => { run('UPDATE bank_letters SET read = 1 WHERE id = ? AND user_id = ?', Number(req.params.id), req.user.id); return true; }));
r.get('/certificates', h((req) => all('SELECT * FROM certificates WHERE user_id = ? ORDER BY id DESC', req.user.id)));

/** 清偿中心概览：一次取齐首页所需数据 */
r.get('/overview', h((req) => {
  const uid = req.user.id;
  const debts = all('SELECT * FROM debt_cases WHERE user_id = ?', uid);
  const total = r2(debts.reduce((a, d) => a + d.principal, 0));
  const out = r2(debts.reduce((a, d) => a + d.outstanding, 0));
  return {
    credit_score: one('SELECT credit_score FROM users WHERE id = ?', uid).credit_score,
    balance: dpSummary(uid),
    bills: { count: debts.filter((d) => d.status !== 3).length, settled: debts.filter((d) => d.status === 3).length, total, outstanding: out, cleared: r2(total - out), progress: total > 0 ? r2((total - out) / total) : 0 },
    clearing: one('SELECT COUNT(*) n FROM clearances WHERE user_id = ? AND status IN (10,20,30)', uid).n,
    unread_letters: one('SELECT COUNT(*) n FROM bank_letters WHERE user_id = ? AND read = 0', uid).n,
    certificates: one('SELECT COUNT(*) n FROM certificates WHERE user_id = ?', uid).n,
    unread_notifications: one('SELECT COUNT(*) n FROM notifications WHERE user_id = ? AND read = 0', uid).n,
  };
}));

// 钱包 & 通知
r.get('/wallet', h((req) => ({ balance: one('SELECT wallet_balance FROM users WHERE id = ?', req.user.id).wallet_balance, txs: all('SELECT * FROM wallet_txs WHERE user_id = ? ORDER BY id DESC LIMIT 50', req.user.id) })));
r.post('/wallet/recharge', h((req) => {
  if (!DEMO_MODE) throw E.forbidden('充值需接入真实支付通道');
  const amt = num(req.body.amount, 'amount', { min: 1, max: 50000 });
  const bal = r2(req.user.wallet_balance + amt);
  run('UPDATE users SET wallet_balance = ? WHERE id = ?', bal, req.user.id);
  run('INSERT INTO wallet_txs (user_id, type, title, amount, balance_after, created_at) VALUES (?,?,?,?,?,?)', req.user.id, 'recharge', '模拟充值', amt, bal, nowIso());
  return { balance: bal };
}));
r.get('/notifications', h((req) => all('SELECT * FROM notifications WHERE user_id = ? ORDER BY id DESC LIMIT 50', req.user.id)));
r.post('/notifications/read-all', h((req) => { run('UPDATE notifications SET read = 1 WHERE user_id = ?', req.user.id); return true; }));

export default r;
