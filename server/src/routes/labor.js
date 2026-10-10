/** App 端：微劳动 / 商家工作台 / 社区 / 实名提现 / AI / 银行专员 / 风控专员 */
import { Router } from 'express';
import multer from 'multer';
import path from 'node:path';
import crypto from 'node:crypto';
import { ROOT, all, nowIso, one, r2, run } from '../db.js';
import { requireUser } from '../auth.js';
import { E, h, num, str } from '../errors.js';
import { CLEAR_STATUS, processClearance } from '../services/finance.js';
import { ORDER_STATUS, TASK_TYPES, abandonOrder, acceptTask, arbitrate, closeTask, disputeOrder, laborSummary, orderView, publishTask, reviewOrder, submitOrder, taskView } from '../services/labor.js';
import { AGENTS, KYC, POST_STATUS, WD_STATUS, chat, createPost, kycOf, kycStep, likePost, moderatePost, postView, processWithdraw, requestWithdraw } from '../services/account.js';
import { riskCases } from '../services/risk.js';
import { bankByCode } from '../services/bank.js';

const r = Router();

// 公开：任务类型
r.get('/labor/types', h(() => Object.entries(TASK_TYPES).map(([k, v]) => ({ key: k, ...v, count: one('SELECT COUNT(*) n FROM tasks WHERE status = 2 AND task_type = ?', k).n }))));

r.use('/labor', requireUser);
r.use(['/merchant', '/community', '/kyc', '/wallet2', '/ai', '/bank-desk', '/risk-desk', '/session'], requireUser);

// 图片上传（交付物 / 社区配图）
const upload = multer({
  storage: multer.diskStorage({
    destination: path.join(ROOT, 'public', 'uploads'),
    filename: (_req, file, cb) => cb(null, `u${Date.now()}-${crypto.randomBytes(4).toString('hex')}${(path.extname(file.originalname) || '.jpg').toLowerCase()}`),
  }),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => cb(null, /^image\/(png|jpe?g|webp|gif)$/.test(file.mimetype) || /\.(png|jpe?g|webp|gif)$/i.test(file.originalname)),
});
r.post('/upload', requireUser, upload.single('file'), h((req) => {
  if (!req.file) throw E.bad('请上传 png/jpg/webp 图片（≤8MB）');
  return { url: `/uploads/${req.file.filename}` };
}));

/** 当前账号身份（App 据此切换界面） */
r.get('/session', h((req) => ({ id: req.user.id, ext_id: req.user.ext_id, role: req.user.role, org_name: req.user.org_name, bank_code: req.user.bank_code, nickname: req.user.nickname })));

// ───────── 微劳动（用户） ─────────
r.get('/labor/tasks', h((req) => {
  const w = ['t.status = 2', 't.deadline_at > ?'];
  const p = [nowIso()];
  if (req.query.type) { w.push('t.task_type = ?'); p.push(String(req.query.type)); }
  if (req.query.keyword) { w.push('(t.title LIKE ? OR t.publisher_name LIKE ?)'); p.push(`%${req.query.keyword}%`, `%${req.query.keyword}%`); }
  if (req.query.remote === '1') w.push('t.city IS NULL');
  const order = { reward: 't.reward DESC', new: 't.id DESC', quick: 't.duration_hours ASC, t.reward DESC', clear: '(t.reward * t.clear_pct) DESC' }[req.query.sort] || '(t.taken * 1.0 / t.quota) DESC, t.id DESC';
  return all(`SELECT t.* FROM tasks t WHERE ${w.join(' AND ')} ORDER BY ${order} LIMIT 200`, ...p).map((t) => taskView(t, req.user.id));
}));
r.get('/labor/tasks/:id', h((req) => {
  const t = one('SELECT * FROM tasks WHERE id = ?', Number(req.params.id));
  if (!t) throw E.notFound('任务不存在');
  const v = taskView(t, req.user.id);
  v.publisher = one('SELECT nickname, org_name, credit_score FROM users WHERE id = ?', t.publisher_id);
  v.publisher_stats = one('SELECT COUNT(*) tasks, COALESCE(SUM(done),0) done FROM tasks WHERE publisher_id = ?', t.publisher_id);
  return v;
}));
r.post('/labor/tasks/:id/accept', h((req) => acceptTask(req.user, Number(req.params.id))));
r.get('/labor/orders', h((req) => {
  const st = req.query.group;
  const map = { active: '10,20,40,45,50,55', done: '60,80', closed: '70,31,32' };
  const w = map[st] ? `AND status IN (${map[st]})` : '';
  return all(`SELECT * FROM task_orders WHERE user_id = ? ${w} ORDER BY updated_at DESC LIMIT 200`, req.user.id).map(orderView);
}));
r.get('/labor/orders/:id', h((req) => {
  const o = one('SELECT * FROM task_orders WHERE id = ? AND user_id = ?', Number(req.params.id), req.user.id);
  if (!o) throw E.notFound('任务单不存在');
  return orderView(o);
}));
r.post('/labor/orders/:id/submit', h((req) => submitOrder(req.user, Number(req.params.id), req.body)));
r.post('/labor/orders/:id/abandon', h((req) => abandonOrder(req.user, Number(req.params.id))));
r.post('/labor/orders/:id/dispute', h((req) => disputeOrder(req.user, Number(req.params.id), req.body.reason)));
r.get('/labor/summary', h((req) => laborSummary(req.user.id)));

// ───────── 商家工作台 ─────────
const needMerchant = (req) => { if (req.user.role !== 'merchant') throw E.forbidden('仅商家账号可用'); };
r.get('/merchant/overview', h((req) => {
  needMerchant(req);
  const uid = req.user.id;
  const u = one('SELECT wallet_balance, wallet_frozen FROM users WHERE id = ?', uid);
  return {
    wallet: u.wallet_balance, frozen: u.wallet_frozen,
    tasks: one('SELECT COUNT(*) total, SUM(status = 2) live, COALESCE(SUM(done),0) done, COALESCE(SUM(reward * done),0) spent FROM tasks WHERE publisher_id = ?', uid),
    to_review: one('SELECT COUNT(*) n FROM task_orders o JOIN tasks t ON t.id = o.task_id WHERE t.publisher_id = ? AND o.status = 50', uid).n,
    disputes: one('SELECT COUNT(*) n FROM task_orders o JOIN tasks t ON t.id = o.task_id WHERE t.publisher_id = ? AND o.status = 55', uid).n,
  };
}));
r.get('/merchant/tasks', h((req) => {
  needMerchant(req);
  return all('SELECT * FROM tasks WHERE publisher_id = ? ORDER BY id DESC', req.user.id).map((t) => ({ ...taskView(t), pending: one('SELECT COUNT(*) n FROM task_orders WHERE task_id = ? AND status = 50', t.id).n }));
}));
r.post('/merchant/tasks', h((req) => { needMerchant(req); return publishTask(req.user, req.body); }));
r.post('/merchant/tasks/:id/close', h((req) => { needMerchant(req); return closeTask(req.user.id, Number(req.params.id)); }));
r.get('/merchant/orders', h((req) => {
  needMerchant(req);
  const st = req.query.status ? Number(req.query.status) : 50;
  const tid = req.query.task_id ? Number(req.query.task_id) : null;
  return all(`SELECT o.* FROM task_orders o JOIN tasks t ON t.id = o.task_id WHERE t.publisher_id = ? AND o.status = ? ${tid ? 'AND o.task_id = ?' : ''} ORDER BY o.updated_at DESC LIMIT 200`, req.user.id, st, ...(tid ? [tid] : [])).map(orderView);
}));
r.post('/merchant/orders/:id/review', h((req) => { needMerchant(req); return reviewOrder(req.user, Number(req.params.id), !!req.body.approve, req.body.note, req.body.rating); }));
r.post('/merchant/recharge', h((req) => {
  needMerchant(req);
  const amt = num(req.body.amount, 'amount', { min: 100, max: 1000000 });
  const bal = r2(req.user.wallet_balance + amt);
  run('UPDATE users SET wallet_balance = ? WHERE id = ?', bal, req.user.id);
  run('INSERT INTO wallet_txs (user_id, type, title, amount, balance_after, created_at) VALUES (?,?,?,?,?,?)', req.user.id, 'recharge', '商家充值（模拟）', amt, bal, nowIso());
  return { balance: bal };
}));

// ───────── 社区 ─────────
r.get('/community/posts', h((req) => {
  const mine = req.query.mine === '1';
  const order = req.query.tab === 'new' ? 'p.id DESC' : 'p.status DESC, (p.likes + p.comments * 2) DESC';
  const rows = mine ? all('SELECT * FROM posts p WHERE user_id = ? ORDER BY id DESC', req.user.id) : all(`SELECT * FROM posts p WHERE status IN (1,2) ORDER BY ${order} LIMIT 100`);
  return rows.map((p) => postView(p, req.user.id));
}));
r.get('/community/posts/:id', h((req) => {
  const p = one('SELECT * FROM posts WHERE id = ?', Number(req.params.id));
  if (!p || (![1, 2].includes(p.status) && p.user_id !== req.user.id)) throw E.notFound('内容不存在');
  run('UPDATE posts SET views = views + 1 WHERE id = ?', p.id);
  return { ...postView(p, req.user.id), comment_list: all('SELECT c.*, u.nickname FROM post_comments c JOIN users u ON u.id = c.user_id WHERE post_id = ? ORDER BY c.id DESC LIMIT 100', p.id) };
}));
r.post('/community/posts', h((req) => createPost(req.user, req.body)));
r.post('/community/posts/:id/like', h((req) => likePost(req.user.id, Number(req.params.id))));
r.post('/community/posts/:id/comments', h((req) => {
  const p = one('SELECT * FROM posts WHERE id = ? AND status IN (1,2)', Number(req.params.id));
  if (!p) throw E.notFound('内容不存在');
  const body = str(req.body.body, '评论', { max: 300 });
  if (/加微信|加V|征信修复|内部渠道/i.test(body)) throw E.bad('评论包含违规内容');
  run('INSERT INTO post_comments (post_id, user_id, body, created_at) VALUES (?,?,?,?)', p.id, req.user.id, body, nowIso());
  run('UPDATE posts SET comments = comments + 1 WHERE id = ?', p.id);
  return true;
}));
r.get('/community/earnings', h((req) => ({
  total: r2(one('SELECT COALESCE(SUM(revenue),0) s FROM posts WHERE user_id = ?', req.user.id).s),
  posts: one('SELECT COUNT(*) n FROM posts WHERE user_id = ? AND status IN (1,2)', req.user.id).n,
  likes: one('SELECT COALESCE(SUM(likes),0) s FROM posts WHERE user_id = ?', req.user.id).s,
})));

// ───────── 实名 / 钱包提现 ─────────
r.get('/kyc', h((req) => kycOf(req.user.id)));
r.post('/kyc/:step', h((req) => kycStep(req.user.id, req.params.step, req.body)));
r.get('/wallet2', h((req) => {
  const u = one('SELECT wallet_balance, wallet_frozen FROM users WHERE id = ?', req.user.id);
  const income = one("SELECT COALESCE(SUM(CASE WHEN type = 'task_income' THEN amount END),0) labor, COALESCE(SUM(CASE WHEN type = 'content_income' THEN amount END),0) content FROM wallet_txs WHERE user_id = ?", req.user.id);
  return {
    balance: u.wallet_balance, frozen: u.wallet_frozen, income,
    withdrawing: r2(one('SELECT COALESCE(SUM(amount),0) s FROM withdrawals WHERE user_id = ? AND status IN (10,20)', req.user.id).s),
    kyc: kycOf(req.user.id),
    txs: all('SELECT * FROM wallet_txs WHERE user_id = ? ORDER BY id DESC LIMIT 60', req.user.id),
    withdrawals: all('SELECT * FROM withdrawals WHERE user_id = ? ORDER BY id DESC LIMIT 30', req.user.id).map((w) => ({ ...w, status_label: WD_STATUS[w.status] })),
  };
}));
r.post('/wallet2/withdraw', h((req) => requestWithdraw(req.user, req.body)));

// ───────── AI 助手 ─────────
r.get('/ai/agents', h(() => Object.entries(AGENTS).map(([k, v]) => ({ key: k, ...v }))));
r.get('/ai/:agent/messages', h((req) => all('SELECT role, content, created_at FROM ai_messages WHERE user_id = ? AND agent = ? ORDER BY id DESC LIMIT 40', req.user.id, req.params.agent).reverse()));
r.post('/ai/:agent/chat', h((req) => chat(req.user.id, req.params.agent, req.body.message)));
r.delete('/ai/:agent/messages', h((req) => { run('DELETE FROM ai_messages WHERE user_id = ? AND agent = ?', req.user.id, req.params.agent); return true; }));

// ───────── 银行专员工作台（只看本行数据） ─────────
const needBank = (req) => {
  if (req.user.role !== 'bank' || !req.user.bank_code) throw E.forbidden('仅合作银行专员可用');
  return bankByCode(req.user.bank_code);
};
r.get('/bank-desk/overview', h((req) => {
  const b = needBank(req);
  const code = req.user.bank_code;
  return {
    bank: b,
    cases: one('SELECT COUNT(*) n, COALESCE(SUM(principal),0) principal, COALESCE(SUM(outstanding),0) outstanding, COALESCE(SUM(cleared),0) cleared, SUM(status = 3) settled FROM debt_cases WHERE bank_code = ?', code),
    queue: one('SELECT COUNT(*) n, COALESCE(SUM(points),0) amt FROM clearances cl JOIN debt_cases d ON d.id = cl.case_id WHERE d.bank_code = ? AND cl.status IN (10,20,30)', code),
    received: r2(one('SELECT COALESCE(SUM(cash_remitted),0) s FROM clearances cl JOIN debt_cases d ON d.id = cl.case_id WHERE d.bank_code = ? AND cl.status IN (30,50)', code).s),
    certificates: one('SELECT COUNT(*) n FROM certificates c JOIN debt_cases d ON d.id = c.case_id WHERE d.bank_code = ?', code).n,
  };
}));
r.get('/bank-desk/clearances', h((req) => {
  needBank(req);
  const st = req.query.status ? `AND cl.status = ${Number(req.query.status)}` : 'AND cl.status IN (10,20,30)';
  return all(`SELECT cl.*, d.creditor, d.case_no, d.outstanding, d.principal, u.nickname FROM clearances cl JOIN debt_cases d ON d.id = cl.case_id JOIN users u ON u.id = cl.user_id WHERE d.bank_code = ? ${st} ORDER BY cl.id DESC LIMIT 200`, req.user.bank_code).map((c) => ({ ...c, status_label: CLEAR_STATUS[c.status], history: JSON.parse(c.history_json) }));
}));
r.post('/bank-desk/clearances/:id/:action', h((req) => {
  needBank(req);
  const cl = one('SELECT cl.id FROM clearances cl JOIN debt_cases d ON d.id = cl.case_id WHERE cl.id = ? AND d.bank_code = ?', Number(req.params.id), req.user.bank_code);
  if (!cl) throw E.notFound('不是本行的清偿单');
  if (!['accept', 'write-off', 'reject'].includes(req.params.action)) throw E.forbidden('资金划转由平台操作');
  return processClearance(cl.id, req.params.action, `BANK:${req.user.nickname}`, req.body);
}));
r.get('/bank-desk/cases', h((req) => {
  needBank(req);
  return all('SELECT d.*, u.nickname FROM debt_cases d JOIN users u ON u.id = d.user_id WHERE d.bank_code = ? ORDER BY d.status, d.outstanding DESC LIMIT 300', req.user.bank_code);
}));

// ───────── 风控 / 运营 专员（App 端轻量工作台） ─────────
const needStaff = (req, roles) => { if (!roles.includes(req.user.role)) throw E.forbidden('无权访问'); };
r.get('/risk-desk/overview', h((req) => {
  needStaff(req, ['risk', 'ops']);
  return {
    open_cases: one('SELECT COUNT(*) n FROM risk_cases WHERE status = 0').n,
    withdraw_review: one('SELECT COUNT(*) n, COALESCE(SUM(amount),0) amt FROM withdrawals WHERE status = 10'),
    task_audit: one('SELECT COUNT(*) n FROM tasks WHERE status = 1').n,
    disputes: one('SELECT COUNT(*) n FROM task_orders WHERE status = 55').n,
    posts_review: one('SELECT COUNT(*) n FROM posts WHERE status = 0').n,
    rules: all('SELECT * FROM risk_rules ORDER BY scene, code'),
  };
}));
r.get('/risk-desk/cases', h((req) => { needStaff(req, ['risk', 'ops']); return riskCases(req.query.status != null && req.query.status !== '' ? Number(req.query.status) : 0); }));
r.post('/risk-desk/cases/:id', h((req) => {
  needStaff(req, ['risk', 'ops']);
  const st = { pass: 1, block: 2, freeze: 3 }[req.body.action];
  if (!st) throw E.bad('未知操作');
  const c = one('SELECT * FROM risk_cases WHERE id = ?', Number(req.params.id));
  if (!c) throw E.notFound('案件不存在');
  run('UPDATE risk_cases SET status = ?, handled_by = ?, note = ?, handled_at = ? WHERE id = ?', st, req.user.nickname, req.body.note || null, nowIso(), c.id);
  if (st === 3) run('UPDATE users SET status = 2 WHERE id = ?', c.user_id);
  if (c.ref_type === 'withdrawal') {
    const w = one('SELECT status FROM withdrawals WHERE id = ?', c.ref_id);
    if (w?.status === 10) processWithdraw(c.ref_id, st === 1 ? 'approve' : 'reject', st === 1 ? null : req.body.note || '风控拦截');
  }
  if (c.ref_type === 'post') moderatePost(c.ref_id, st === 1 ? 'approve' : 'block', req.body.note);
  return one('SELECT * FROM risk_cases WHERE id = ?', c.id);
}));
r.get('/risk-desk/withdrawals', h((req) => { needStaff(req, ['risk', 'ops']); return all('SELECT w.*, u.nickname FROM withdrawals w JOIN users u ON u.id = w.user_id WHERE w.status = 10 ORDER BY w.id DESC').map((w) => ({ ...w, risk_hits: JSON.parse(w.risk_hits), status_label: WD_STATUS[w.status] })); }));
r.post('/risk-desk/withdrawals/:id', h((req) => { needStaff(req, ['risk', 'ops']); return processWithdraw(Number(req.params.id), req.body.action, req.body.note); }));
r.get('/risk-desk/disputes', h((req) => { needStaff(req, ['risk', 'ops']); return all('SELECT * FROM task_orders WHERE status = 55 ORDER BY updated_at').map(orderView); }));
r.post('/risk-desk/disputes/:id', h((req) => { needStaff(req, ['risk', 'ops']); return arbitrate(Number(req.params.id), !!req.body.approve, req.body.note, `STAFF:${req.user.nickname}`); }));
r.get('/risk-desk/posts', h((req) => { needStaff(req, ['risk', 'ops']); return all('SELECT * FROM posts WHERE status = 0 ORDER BY id').map((p) => postView(p)); }));
r.post('/risk-desk/posts/:id', h((req) => { needStaff(req, ['risk', 'ops']); return moderatePost(Number(req.params.id), req.body.action, req.body.note); }));

void ORDER_STATUS; void KYC; void POST_STATUS;
export default r;
