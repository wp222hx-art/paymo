import { Router } from 'express';
import multer from 'multer';
import path from 'node:path';
import crypto from 'node:crypto';
import { all, nowIso, one, r2, ROOT, run, tx } from '../db.js';
import { checkPassword, hashPassword, requireAdmin, sign } from '../auth.js';
import { E, h, num, str } from '../errors.js';
import { CLEAR_STATUS, issueDp, notify, postLedger, processClearance, quoteMultiplier, settleCommission, settleDueCommissions } from '../services/finance.js';
import { COMMISSION_STATUS, ORDER_STATUS, getOrder, orderView, reviewRefund, runOrderJobs, shipOrder } from '../services/orders.js';
import { arbitrate, auditTask, orderView as laborOrderView, runLaborJobs, taskView as laborTaskView } from '../services/labor.js';
import { WD_STATUS, moderatePost, postView, processWithdraw, settleContentRevenue } from '../services/account.js';
import { riskCases } from '../services/risk.js';

const r = Router();

const log = (req, action, target, detail) => run('INSERT INTO admin_logs (admin, action, target, detail, created_at) VALUES (?,?,?,?,?)', req.admin.username, action, target ?? null, detail ? JSON.stringify(detail) : null, nowIso());

// 登录失败限流：同一用户名 10 分钟内最多 5 次
const fails = new Map();
r.post('/login', h((req) => {
  const username = str(req.body.username, '用户名');
  const f = fails.get(username);
  if (f && f.n >= 5 && Date.now() - f.at < 600_000) throw E.forbidden('失败次数过多，请 10 分钟后再试');
  const a = one('SELECT * FROM admins WHERE username = ?', username);
  if (!a || !checkPassword(String(req.body.password || ''), a.password_hash)) {
    fails.set(username, { n: (f && Date.now() - f.at < 600_000 ? f.n : 0) + 1, at: Date.now() });
    throw E.bad('用户名或密码错误');
  }
  fails.delete(username);
  return { token: sign({ typ: 'admin', aid: a.id }, 12 * 3600), admin: { id: a.id, username: a.username, name: a.name } };
}));

r.use(requireAdmin);

r.get('/me', h((req) => req.admin));
r.post('/password', h((req) => {
  const a = one('SELECT * FROM admins WHERE id = ?', req.admin.id);
  if (!checkPassword(String(req.body.old_password || ''), a.password_hash)) throw E.bad('原密码错误');
  const np = str(req.body.new_password, '新密码', { min: 8, max: 64 });
  run('UPDATE admins SET password_hash = ? WHERE id = ?', hashPassword(np), a.id);
  log(req, 'change_password', a.username);
  return true;
}));

// ───────── 图片上传 ─────────
const upload = multer({
  storage: multer.diskStorage({
    destination: path.join(ROOT, 'public', 'uploads'),
    filename: (_req, file, cb) => cb(null, `${Date.now()}-${crypto.randomBytes(4).toString('hex')}${path.extname(file.originalname).toLowerCase()}`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => cb(null, /^image\/(png|jpe?g|webp|gif)$/.test(file.mimetype)),
});
r.post('/upload', upload.single('file'), h((req) => {
  if (!req.file) throw E.bad('请上传 png/jpg/webp/gif 图片（≤5MB）');
  return { url: `/uploads/${req.file.filename}` };
}));

// ───────── 看板 ─────────
r.get('/dashboard', h(() => {
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const t = today.toISOString();
  const paid = '(20,30,40,60)';
  const s = (sql, ...p) => one(sql, ...p);
  const trend = [];
  for (let i = 13; i >= 0; i--) {
    const d0 = new Date(today.getTime() - i * 86400_000);
    const d1 = new Date(d0.getTime() + 86400_000);
    const x = s(`SELECT COUNT(*) n, COALESCE(SUM(pay_amount),0) gmv, COALESCE(SUM(commission_amount),0) cm FROM orders WHERE status IN ${paid} AND paid_at >= ? AND paid_at < ?`, d0.toISOString(), d1.toISOString());
    trend.push({ date: d0.toISOString().slice(5, 10), orders: x.n, gmv: r2(x.gmv), commission: r2(x.cm) });
  }
  return {
    today: s(`SELECT COUNT(*) orders, COALESCE(SUM(pay_amount),0) gmv, COALESCE(SUM(commission_amount),0) commission FROM orders WHERE status IN ${paid} AND paid_at >= ?`, t),
    total: s(`SELECT COUNT(*) orders, COALESCE(SUM(pay_amount),0) gmv, COALESCE(SUM(commission_amount),0) commission, COALESCE(SUM(dp_amount),0) dp FROM orders WHERE status IN ${paid}`),
    users: s('SELECT COUNT(*) n FROM users').n,
    products: s('SELECT COUNT(*) total, SUM(status = 1) online, SUM(stock < 20 AND status = 1) low_stock FROM products'),
    todo: {
      to_ship: s('SELECT COUNT(*) n FROM orders WHERE status = 20').n,
      refunding: s('SELECT COUNT(*) n FROM orders WHERE status = 60').n,
      clearances: s('SELECT COUNT(*) n FROM clearances WHERE status IN (10,20,30)').n,
      commissions_due: s('SELECT COUNT(*) n FROM commissions WHERE status = 1 AND settle_at <= ?', nowIso()).n,
      task_audit: s('SELECT COUNT(*) n FROM tasks WHERE status = 1').n,
      disputes: s('SELECT COUNT(*) n FROM task_orders WHERE status = 55').n,
      withdrawals: s('SELECT COUNT(*) n FROM withdrawals WHERE status = 10').n,
      risk_cases: s('SELECT COUNT(*) n FROM risk_cases WHERE status = 0').n,
      posts: s('SELECT COUNT(*) n FROM posts WHERE status = 0').n,
    },
    commission: s('SELECT COALESCE(SUM(CASE WHEN status=0 THEN commission END),0) estimated, COALESCE(SUM(CASE WHEN status=1 THEN commission END),0) pending, COALESCE(SUM(CASE WHEN status=2 THEN commission END),0) settled FROM commissions'),
    dp: s('SELECT COALESCE(SUM(face_value),0) issued, COALESCE(SUM(consumed),0) consumed, COALESCE(SUM(cash_backed * (face_value - consumed) / face_value),0) reserve FROM dp_batches WHERE face_value > 0'),
    debt: s('SELECT COALESCE(SUM(principal),0) principal, COALESCE(SUM(cleared),0) cleared, SUM(status = 3) settled_cases, COUNT(*) cases FROM debt_cases'),
    certificates: s('SELECT COUNT(*) n FROM certificates').n,
    trend,
  };
}));

// ───────── 分类 ─────────
r.get('/categories', h(() => all('SELECT c.*, pc.name parent_name, (SELECT COUNT(*) FROM products p WHERE p.category_id = c.id) product_count, (SELECT COUNT(*) FROM categories s WHERE s.parent_id = c.id) child_count FROM categories c LEFT JOIN categories pc ON pc.id = c.parent_id ORDER BY COALESCE(pc.sort, c.sort), COALESCE(c.parent_id, c.id), c.parent_id IS NOT NULL, c.sort, c.id')));
r.post('/categories', h((req) => {
  const name = str(req.body.name, '分类名称', { max: 20 });
  if (one('SELECT id FROM categories WHERE name = ?', name)) throw E.conflict('分类名称已存在');
  const x = run('INSERT INTO categories (name, icon, image, sort, status, parent_id, created_at) VALUES (?,?,?,?,?,?,?)', name, req.body.icon || '🛍️', req.body.image || null, Number(req.body.sort) || 0, req.body.status === 0 ? 0 : 1, req.body.parent_id ? Number(req.body.parent_id) : null, nowIso());
  log(req, 'category.create', name);
  return one('SELECT * FROM categories WHERE id = ?', Number(x.lastInsertRowid));
}));
r.put('/categories/:id', h((req) => {
  const c = one('SELECT * FROM categories WHERE id = ?', Number(req.params.id));
  if (!c) throw E.notFound('分类不存在');
  const name = str(req.body.name ?? c.name, '分类名称', { max: 20 });
  if (one('SELECT id FROM categories WHERE name = ? AND id != ?', name, c.id)) throw E.conflict('分类名称已存在');
  const pid = req.body.parent_id === undefined ? c.parent_id : (req.body.parent_id ? Number(req.body.parent_id) : null);
  if (pid === c.id) throw E.bad('不能把自己设为上级分类');
  run('UPDATE categories SET name = ?, icon = ?, image = ?, sort = ?, status = ?, parent_id = ? WHERE id = ?', name, req.body.icon ?? c.icon, req.body.image ?? c.image, Number(req.body.sort ?? c.sort), Number(req.body.status ?? c.status), pid, c.id);
  log(req, 'category.update', name, req.body);
  return one('SELECT * FROM categories WHERE id = ?', c.id);
}));
r.delete('/categories/:id', h((req) => {
  const id = Number(req.params.id);
  if (one('SELECT id FROM products WHERE category_id = ? LIMIT 1', id)) throw E.conflict('分类下还有商品，请先迁移或删除商品');
  if (one('SELECT id FROM categories WHERE parent_id = ? LIMIT 1', id)) throw E.conflict('分类下还有子分类，请先删除子分类');
  if (one('SELECT id FROM offset_rules WHERE category_id = ? LIMIT 1', id)) throw E.conflict('该分类有关联的倍率规则，请先删除规则');
  run('DELETE FROM categories WHERE id = ?', id);
  log(req, 'category.delete', String(id));
  return true;
}));

// ───────── 商品 ─────────
r.get('/products', h((req) => {
  const page = num(req.query.page ?? 1, 'page', { min: 1, int: true });
  const size = num(req.query.size ?? 20, 'size', { min: 1, max: 200, int: true });
  const w = ['1=1'];
  const p = [];
  if (req.query.category_id) { w.push('(p.category_id = ? OR p.category_id IN (SELECT id FROM categories WHERE parent_id = ?))'); p.push(Number(req.query.category_id), Number(req.query.category_id)); }
  if (req.query.status !== undefined && req.query.status !== '') { w.push('p.status = ?'); p.push(Number(req.query.status)); }
  if (req.query.keyword) { w.push('(p.name LIKE ? OR p.merchant LIKE ?)'); p.push(`%${req.query.keyword}%`, `%${req.query.keyword}%`); }
  const ws = w.join(' AND ');
  const total = one(`SELECT COUNT(*) n FROM products p WHERE ${ws}`, ...p).n;
  const list = all(`SELECT p.*, c.name category_name FROM products p JOIN categories c ON c.id = p.category_id WHERE ${ws} ORDER BY p.sort, p.id DESC LIMIT ? OFFSET ?`, ...p, size, (page - 1) * size).map((x) => {
    const q = quoteMultiplier(x.category_id, 600);
    const commission = r2((x.price * x.commission_rate) / 100);
    return { ...x, commission, base_multiplier: q.multiplier, base_dp: r2(commission * q.multiplier) };
  });
  return { list, total, page, size };
}));
r.get('/products/:id', h((req) => {
  const p = one('SELECT * FROM products WHERE id = ?', Number(req.params.id));
  if (!p) throw E.notFound('商品不存在');
  return p;
}));
const productBody = (b, old = {}) => {
  const v = { ...old, ...b };
  const cat = one('SELECT id FROM categories WHERE id = ?', Number(v.category_id));
  if (!cat) throw E.bad('请选择有效分类');
  return [
    cat.id, str(v.name, '商品名称', { max: 60 }), String(v.subtitle ?? '').slice(0, 100), String(v.description ?? '').slice(0, 2000), str(v.merchant ?? '新光云自营', '商家', { max: 40 }),
    v.image || null, v.emoji || '🛍️', r2(num(v.price, '售价', { min: 0.01, max: 1_000_000 })), v.original_price ? r2(num(v.original_price, '原价', { min: 0 })) : null,
    r2(num(v.commission_rate, '佣金率', { min: 0, max: 90 })), num(v.stock ?? 0, '库存', { min: 0, max: 10_000_000, int: true }), Number(v.sort) || 0, Number(v.status ?? 1) ? 1 : 0,
  ];
};
r.post('/products', h((req) => {
  const at = nowIso();
  const x = run('INSERT INTO products (category_id, name, subtitle, description, merchant, image, emoji, price, original_price, commission_rate, stock, sort, status, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', ...productBody(req.body), at, at);
  log(req, 'product.create', req.body.name);
  return one('SELECT * FROM products WHERE id = ?', Number(x.lastInsertRowid));
}));
r.put('/products/:id', h((req) => {
  const old = one('SELECT * FROM products WHERE id = ?', Number(req.params.id));
  if (!old) throw E.notFound('商品不存在');
  run('UPDATE products SET category_id=?, name=?, subtitle=?, description=?, merchant=?, image=?, emoji=?, price=?, original_price=?, commission_rate=?, stock=?, sort=?, status=?, updated_at=? WHERE id=?', ...productBody(req.body, old), nowIso(), old.id);
  log(req, 'product.update', old.name, req.body);
  return one('SELECT * FROM products WHERE id = ?', old.id);
}));
r.post('/products/batch-status', h((req) => {
  const ids = (req.body.ids || []).map(Number).filter(Boolean);
  const st = req.body.status ? 1 : 0;
  for (const id of ids) run('UPDATE products SET status = ?, updated_at = ? WHERE id = ?', st, nowIso(), id);
  log(req, st ? 'product.online' : 'product.offline', ids.join(','));
  return { updated: ids.length };
}));
r.delete('/products/:id', h((req) => {
  const id = Number(req.params.id);
  if (one('SELECT id FROM order_items WHERE product_id = ? LIMIT 1', id)) throw E.conflict('商品已有订单，不能删除，请改为下架');
  run('DELETE FROM cart_items WHERE product_id = ?', id);
  run('DELETE FROM products WHERE id = ?', id);
  log(req, 'product.delete', String(id));
  return true;
}));

// ───────── 订单 ─────────
r.get('/orders', h((req) => {
  const page = num(req.query.page ?? 1, 'page', { min: 1, int: true });
  const size = num(req.query.size ?? 20, 'size', { min: 1, max: 200, int: true });
  const w = ['1=1'];
  const p = [];
  if (req.query.status) { w.push('o.status = ?'); p.push(Number(req.query.status)); }
  if (req.query.keyword) { w.push('(o.order_no LIKE ? OR u.nickname LIKE ? OR u.mobile LIKE ?)'); p.push(`%${req.query.keyword}%`, `%${req.query.keyword}%`, `%${req.query.keyword}%`); }
  const ws = w.join(' AND ');
  const total = one(`SELECT COUNT(*) n FROM orders o JOIN users u ON u.id = o.user_id WHERE ${ws}`, ...p).n;
  const list = all(`SELECT o.*, u.nickname, u.mobile FROM orders o JOIN users u ON u.id = o.user_id WHERE ${ws} ORDER BY o.id DESC LIMIT ? OFFSET ?`, ...p, size, (page - 1) * size).map((o) => ({ ...orderView(o), nickname: o.nickname, mobile: o.mobile }));
  return { list, total, page, size, status_map: ORDER_STATUS };
}));
r.get('/orders/:id', h((req) => {
  const o = getOrder(Number(req.params.id));
  const u = one('SELECT id, nickname, mobile, credit_score FROM users WHERE id = ?', o.user_id);
  return { ...o, user: u };
}));
r.post('/orders/:id/ship', h((req) => { log(req, 'order.ship', req.params.id, req.body); return shipOrder(Number(req.params.id), req.body.express_company, req.body.express_no); }));
r.post('/orders/:id/refund-review', h((req) => { log(req, 'order.refund_review', req.params.id, req.body); return reviewRefund(Number(req.params.id), !!req.body.approve, req.body.reason); }));

// ───────── 佣金 ─────────
r.get('/commissions', h((req) => {
  const w = ['1=1'];
  const p = [];
  if (req.query.status !== undefined && req.query.status !== '') { w.push('cm.status = ?'); p.push(Number(req.query.status)); }
  const list = all(`SELECT cm.*, o.order_no, o.pay_amount, u.nickname FROM commissions cm JOIN orders o ON o.id = cm.order_id JOIN users u ON u.id = cm.user_id WHERE ${w.join(' AND ')} ORDER BY cm.id DESC LIMIT 500`, ...p);
  return { list: list.map((c) => ({ ...c, status_label: COMMISSION_STATUS[c.status], due: c.status === 1 && c.settle_at <= nowIso() })), status_map: COMMISSION_STATUS };
}));
r.post('/commissions/:id/settle', h((req) => { log(req, 'commission.settle', req.params.id); return settleCommission(Number(req.params.id)); }));
r.post('/commissions/settle-due', h((req) => { const n = settleDueCommissions(); log(req, 'commission.settle_due', String(n)); return { settled: n }; }));

// ───────── 倍率规则 ─────────
r.get('/offset-rules', h(() => all('SELECT r.*, c.name category_name FROM offset_rules r LEFT JOIN categories c ON c.id = r.category_id ORDER BY r.rule_type, r.id')));
r.get('/offset-rules/simulate', h((req) => {
  const cats = all('SELECT id, name FROM categories WHERE status = 1 ORDER BY sort');
  const scores = [550, 620, 680, 720];
  return { scores, rows: cats.map((c) => ({ category: c.name, ...Object.fromEntries(scores.map((s) => [s, quoteMultiplier(c.id, s).multiplier])) })) };
}));
const ruleBody = (b) => {
  const type = b.rule_type;
  if (!['category', 'credit_tier', 'global_cap'].includes(type)) throw E.bad('规则类型无效');
  const value = num(b.value, '倍率值', { min: 0, max: 20 });
  if (type === 'global_cap' && value < 1) throw E.bad('全局上限不得低于 1');
  let cat = null;
  if (type === 'category') {
    cat = one('SELECT id FROM categories WHERE id = ?', Number(b.category_id))?.id;
    if (!cat) throw E.bad('请选择分类');
  }
  const mn = type === 'credit_tier' ? num(b.credit_min, '信用分下限', { min: 0, max: 1000, int: true }) : null;
  const mx = type === 'credit_tier' ? num(b.credit_max, '信用分上限', { min: 0, max: 1000, int: true }) : null;
  if (type === 'credit_tier' && mn > mx) throw E.bad('信用分下限不能大于上限');
  return { type, name: str(b.name, '规则名称', { max: 60 }), cat, mn, mx, value, status: num(b.status ?? 0, '状态', { min: 0, max: 3, int: true }) };
};
r.post('/offset-rules', h((req) => {
  const v = ruleBody(req.body);
  const code = `OR-${v.type === 'category' ? 'CAT' : v.type === 'credit_tier' ? 'CR' : 'CAP'}-${Date.now().toString(36).toUpperCase()}`;
  const at = nowIso();
  const x = run('INSERT INTO offset_rules (code, rule_type, name, category_id, credit_min, credit_max, value, status, approved_by, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', code, v.type, v.name, v.cat, v.mn, v.mx, v.value, v.status, v.status === 2 ? req.admin.name : null, at, at);
  log(req, 'offset_rule.create', code, req.body);
  return one('SELECT * FROM offset_rules WHERE id = ?', Number(x.lastInsertRowid));
}));
r.put('/offset-rules/:id', h((req) => {
  const old = one('SELECT * FROM offset_rules WHERE id = ?', Number(req.params.id));
  if (!old) throw E.notFound('规则不存在');
  const v = ruleBody({ ...old, ...req.body });
  run('UPDATE offset_rules SET rule_type=?, name=?, category_id=?, credit_min=?, credit_max=?, value=?, status=?, approved_by=?, updated_at=? WHERE id=?', v.type, v.name, v.cat, v.mn, v.mx, v.value, v.status, v.status === 2 ? req.admin.name : old.approved_by, nowIso(), old.id);
  log(req, 'offset_rule.update', old.code, req.body);
  return one('SELECT * FROM offset_rules WHERE id = ?', old.id);
}));
r.delete('/offset-rules/:id', h((req) => { run('DELETE FROM offset_rules WHERE id = ?', Number(req.params.id)); log(req, 'offset_rule.delete', req.params.id); return true; }));

// ───────── 用户 / 债务 / 积分 ─────────
r.get('/users', h((req) => {
  const kw = req.query.keyword ? `%${req.query.keyword}%` : '%';
  return all(`SELECT u.*,
    (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id AND o.status IN (20,30,40)) order_count,
    (SELECT COALESCE(SUM(face_value - consumed),0) FROM dp_batches b WHERE b.user_id = u.id) dp_available,
    (SELECT COALESCE(SUM(outstanding),0) FROM debt_cases d WHERE d.user_id = u.id) debt_outstanding
    FROM users u WHERE u.nickname LIKE ? OR u.mobile LIKE ? OR COALESCE(u.ext_id,'') LIKE ? ORDER BY u.id LIMIT 500`, kw, kw, kw);
}));
r.get('/users/:id', h((req) => {
  const id = Number(req.params.id);
  const u = one('SELECT * FROM users WHERE id = ?', id);
  if (!u) throw E.notFound('用户不存在');
  return { user: u, debts: all('SELECT * FROM debt_cases WHERE user_id = ?', id), batches: all('SELECT * FROM dp_batches WHERE user_id = ? ORDER BY id DESC', id), orders: all('SELECT * FROM orders WHERE user_id = ? ORDER BY id DESC LIMIT 20', id).map((o) => orderView(o)) };
}));
r.patch('/users/:id', h((req) => {
  const u = one('SELECT * FROM users WHERE id = ?', Number(req.params.id));
  if (!u) throw E.notFound('用户不存在');
  if (req.body.status !== undefined) run('UPDATE users SET status = ? WHERE id = ?', req.body.status === 2 ? 2 : 1, u.id);
  if (req.body.credit_score !== undefined) run('UPDATE users SET credit_score = ? WHERE id = ?', num(req.body.credit_score, '信用分', { min: 300, max: 1000, int: true }), u.id);
  log(req, 'user.update', String(u.id), req.body);
  return one('SELECT * FROM users WHERE id = ?', u.id);
}));
/** 人工补发积分（需注明现金背书来源，计入备付金） */
r.post('/users/:id/grant-dp', h((req) => tx(() => {
  const u = one('SELECT * FROM users WHERE id = ?', Number(req.params.id));
  if (!u) throw E.notFound('用户不存在');
  const face = num(req.body.points, '积分', { min: 0.01, max: 100000 });
  const cash = num(req.body.cash_backed ?? 0, '现金背书', { min: 0, max: face });
  const reason = str(req.body.reason, '原因', { max: 100 });
  const id = issueDp(u.id, 'admin_grant', face, cash, 'admin', req.admin.id, `运营补发 · ${reason}`);
  postLedger('dp_grant', `GRANT-${id}`, [['平台营销费用', 'D', cash], [`债务积分现金备付金·U${u.id}`, 'C', cash]]);
  notify(u.id, '债务积分到账', `运营补发 ${face.toFixed(2)} DP：${reason}`);
  log(req, 'dp.grant', String(u.id), req.body);
  return { batch_id: id };
})));

r.get('/debts', h(() => all('SELECT d.*, u.nickname FROM debt_cases d JOIN users u ON u.id = d.user_id ORDER BY d.status, d.id')));

// ───────── 清算 ─────────
r.get('/clearances', h((req) => {
  const w = req.query.status ? 'WHERE cl.status = ?' : '';
  const p = req.query.status ? [Number(req.query.status)] : [];
  return all(`SELECT cl.*, d.creditor, d.case_no, d.outstanding, u.nickname FROM clearances cl JOIN debt_cases d ON d.id = cl.case_id JOIN users u ON u.id = cl.user_id ${w} ORDER BY cl.id DESC LIMIT 500`, ...p).map((c) => ({ ...c, status_label: CLEAR_STATUS[c.status], history: JSON.parse(c.history_json) }));
}));
r.post('/clearances/:id/:action', h((req) => {
  const out = processClearance(Number(req.params.id), req.params.action, `ADMIN:${req.admin.name}`, req.body);
  log(req, `clearance.${req.params.action}`, out.clearance_no, req.body);
  return { ...out, status_label: CLEAR_STATUS[out.status] };
}));

// ───────── 微劳动 / 社区 / 提现 / 风控 ─────────
const optStatus = (q, col = 'status') => (q.status !== undefined && q.status !== '' ? [`WHERE ${col} = ?`, [Number(q.status)]] : ['', []]);
r.get('/labor/tasks', h((req) => {
  const [w, p] = optStatus(req.query);
  return all(`SELECT * FROM tasks ${w} ORDER BY id DESC LIMIT 500`, ...p).map((t) => ({ ...laborTaskView(t), pending: one('SELECT COUNT(*) n FROM task_orders WHERE task_id = ? AND status IN (50,55)', t.id).n }));
}));
r.post('/labor/tasks/:id/audit', h((req) => { log(req, 'task.audit', req.params.id, req.body); return auditTask(Number(req.params.id), !!req.body.approve, req.body.reason, req.admin.name); }));
r.get('/labor/orders', h((req) => {
  const [w, p] = optStatus(req.query);
  return all(`SELECT * FROM task_orders ${w} ORDER BY updated_at DESC LIMIT 500`, ...p).map(laborOrderView);
}));
r.post('/labor/orders/:id/arbitrate', h((req) => { log(req, 'task.arbitrate', req.params.id, req.body); return arbitrate(Number(req.params.id), !!req.body.approve, req.body.note, `ADMIN:${req.admin.name}`); }));
r.get('/labor/stats', h(() => ({
  tasks: one('SELECT COUNT(*) total, SUM(status = 2) live, SUM(status = 1) audit, COALESCE(SUM(deposit_left),0) escrow FROM tasks'),
  orders: one('SELECT COUNT(*) total, SUM(status = 80) settled, SUM(status = 55) disputes, SUM(status = 50) reviewing, COALESCE(SUM(gross),0) gross, COALESCE(SUM(fee),0) fee, COALESCE(SUM(cash_amount),0) cash, COALESCE(SUM(clear_amount),0) clear FROM task_orders'),
})));
r.get('/posts', h((req) => {
  const [w, p] = optStatus(req.query);
  return all(`SELECT * FROM posts ${w} ORDER BY id DESC LIMIT 300`, ...p).map((x) => postView(x));
}));
r.post('/posts/settle-revenue', h((req) => { const x = settleContentRevenue(); log(req, 'post.settle_revenue', String(x.settled)); return x; }));
r.post('/posts/:id/:action', h((req) => { log(req, `post.${req.params.action}`, req.params.id, req.body); return moderatePost(Number(req.params.id), req.params.action, req.body.note); }));
r.get('/withdrawals', h((req) => {
  const [w, p] = optStatus(req.query, 'w.status');
  return all(`SELECT w.*, u.nickname FROM withdrawals w JOIN users u ON u.id = w.user_id ${w} ORDER BY w.id DESC LIMIT 300`, ...p).map((x) => ({ ...x, risk_hits: JSON.parse(x.risk_hits), status_label: WD_STATUS[x.status] }));
}));
r.post('/withdrawals/:id/:action', h((req) => { log(req, `withdraw.${req.params.action}`, req.params.id, req.body); return processWithdraw(Number(req.params.id), req.params.action, req.body.note); }));
r.get('/risk/rules', h(() => all('SELECT * FROM risk_rules ORDER BY scene, code')));
r.put('/risk/rules/:code', h((req) => {
  const x = one('SELECT * FROM risk_rules WHERE code = ?', req.params.code);
  if (!x) throw E.notFound('规则不存在');
  run('UPDATE risk_rules SET enabled = ?, threshold = ?, action = ?, score = ? WHERE code = ?', req.body.enabled === undefined ? x.enabled : req.body.enabled ? 1 : 0, req.body.threshold ?? x.threshold, ['pass', 'review', 'block'].includes(req.body.action) ? req.body.action : x.action, Number(req.body.score ?? x.score), x.code);
  log(req, 'risk.rule', x.code, req.body);
  return one('SELECT * FROM risk_rules WHERE code = ?', x.code);
}));
r.get('/risk/cases', h((req) => riskCases(req.query.status !== undefined && req.query.status !== '' ? Number(req.query.status) : null)));
r.post('/risk/cases/:id', h((req) => {
  const st = { pass: 1, block: 2, freeze: 3 }[req.body.action];
  if (!st) throw E.bad('未知操作');
  const c = one('SELECT * FROM risk_cases WHERE id = ?', Number(req.params.id));
  if (!c) throw E.notFound('案件不存在');
  run('UPDATE risk_cases SET status = ?, handled_by = ?, note = ?, handled_at = ? WHERE id = ?', st, req.admin.name, req.body.note || null, nowIso(), c.id);
  if (st === 3) run('UPDATE users SET status = 2 WHERE id = ?', c.user_id);
  if (c.ref_type === 'withdrawal' && one('SELECT status FROM withdrawals WHERE id = ?', c.ref_id)?.status === 10) processWithdraw(c.ref_id, st === 1 ? 'approve' : 'reject', st === 1 ? null : req.body.note || '风控拦截');
  if (c.ref_type === 'post') moderatePost(c.ref_id, st === 1 ? 'approve' : 'block', req.body.note);
  log(req, 'risk.case', String(c.id), req.body);
  return one('SELECT * FROM risk_cases WHERE id = ?', c.id);
}));

// ───────── 银行回函 / 偿清证明 / 银行账单库 ─────────
r.get('/certificates', h(() => all('SELECT c.*, u.nickname FROM certificates c JOIN users u ON u.id = c.user_id ORDER BY c.id DESC')));
r.get('/bank-letters', h(() => all('SELECT l.*, u.nickname FROM bank_letters l JOIN users u ON u.id = l.user_id ORDER BY l.id DESC LIMIT 500')));
r.get('/bank-accounts', h(() => all('SELECT * FROM bank_accounts ORDER BY id DESC LIMIT 500')));

// ───────── 财务 / 设置 / 日志 / 任务 ─────────
r.get('/ledger', h((req) => {
  const kw = req.query.keyword ? `%${req.query.keyword}%` : '%';
  const list = all('SELECT * FROM ledger WHERE biz_ref LIKE ? OR account LIKE ? ORDER BY id DESC LIMIT 500', kw, kw);
  const balances = all("SELECT account, ROUND(SUM(CASE direction WHEN 'D' THEN amount ELSE -amount END), 2) balance FROM ledger GROUP BY account ORDER BY account");
  const check = one("SELECT ROUND(SUM(CASE direction WHEN 'D' THEN amount ELSE 0 END),2) d, ROUND(SUM(CASE direction WHEN 'C' THEN amount ELSE 0 END),2) c FROM ledger");
  return { list, balances, check: { ...check, balanced: Math.abs((check.d || 0) - (check.c || 0)) < 0.01 } };
}));
r.get('/settings', h(() => all('SELECT * FROM settings ORDER BY key')));
r.put('/settings', h((req) => {
  for (const [k, v] of Object.entries(req.body || {})) {
    if (!one('SELECT key FROM settings WHERE key = ?', k)) continue;
    const n = Number(v);
    if (Number.isNaN(n) || n < 0) throw E.bad(`${k} 必须是非负数字`);
    run('UPDATE settings SET value = ? WHERE key = ?', String(n), k);
  }
  log(req, 'settings.update', null, req.body);
  return all('SELECT * FROM settings ORDER BY key');
}));
r.get('/logs', h(() => all('SELECT * FROM admin_logs ORDER BY id DESC LIMIT 300')));
r.post('/jobs/run', h((req) => { const o = runOrderJobs(); const s = settleDueCommissions(); const l = runLaborJobs(); log(req, 'jobs.run', null, { ...o, settled: s, ...l }); return { ...o, settled: s, labor: l }; }));

export default r;
