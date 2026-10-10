// 端到端闭环测试：下单 → 支付 → 发货 → 收货 → 佣金入账(倍率) → 债务清算 → 核销
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'xg-'));
process.env.DATA_DIR = dir;
process.env.ADMIN_PASSWORD = 'test-pass-123';

let base;
let server;
let U;
let A;

const call = async (method, url, body, token) => {
  const res = await fetch(base + url, { method, headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: body ? JSON.stringify(body) : undefined });
  const j = await res.json();
  return j;
};
const okc = async (...a) => {
  const j = await call(...a);
  assert.equal(j.code, 0, `${a[0]} ${a[1]} → ${j.message}`);
  return j.data;
};

before(async () => {
  const { migrate, run } = await import('../src/db.js');
  migrate();
  const { seed } = await import('../src/seed.js');
  seed();
  (await import('../src/seed_labor.js')).seedLabor();
  run("UPDATE settings SET value = '0' WHERE key = 'commission_settle_days'");
  const { createApp } = await import('../src/app.js');
  server = createApp().listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
  U = (await okc('POST', '/api/app/auth/demo-login', { ext_id: 'U1001' })).token;
  A = (await okc('POST', '/api/admin/login', { username: 'admin', password: 'test-pass-123' })).token;
});
after(() => server.close());

test('鉴权', async () => {
  assert.equal((await call('GET', '/api/app/me')).code, 40101);
  assert.equal((await call('GET', '/api/admin/dashboard', null, U)).code, 40101);
  assert.equal((await call('POST', '/api/admin/login', { username: 'admin', password: 'x' })).code, 40001);
});

test('完整闭环：消费 → 佣金 × 倍率 → 债务积分 → 清算核销', async () => {
  const cats = await okc('GET', '/api/app/categories');
  assert.equal(cats.length, 9);
  assert.ok(cats.every((c) => c.children.length > 0));
  const { list } = await okc('GET', `/api/app/products?category_id=${cats.find((c) => c.name === '休闲娱乐').id}`);
  const gym = list.find((p) => p.name.includes('健身月卡'));
  const stock0 = gym.stock;

  // 林晓明信用分 612 → 休闲娱乐 5 + 信用 0.5 = 5.5 倍
  const pv = await okc('POST', '/api/app/orders/preview', { items: [{ product_id: gym.id, qty: 2 }] }, U);
  assert.equal(pv.items[0].multiplier, 5.5);
  assert.equal(pv.freight_amount, 0);
  const expectCommission = Math.round(398 * gym.commission_rate) / 100;
  assert.equal(pv.commission_amount, expectCommission);
  assert.equal(pv.dp_amount, Math.round(expectCommission * 5.5 * 100) / 100);

  await okc('POST', '/api/app/cart', { product_id: gym.id, qty: 2 }, U);
  await okc('POST', '/api/app/addresses', { name: '林晓明', phone: '13800001001', region: '浙江 杭州', detail: '西湖区 1 号' }, U);
  const addr = (await okc('GET', '/api/app/addresses', null, U))[0];
  const order = await okc('POST', '/api/app/orders', { items: [{ product_id: gym.id, qty: 2 }], address_id: addr.id, from_cart: true }, U);
  assert.equal(order.status, 10);
  assert.equal((await okc('GET', '/api/app/cart', null, U)).length, 0, '下单后清空购物车对应商品');
  assert.equal((await okc('GET', `/api/app/products/${gym.id}`)).stock, stock0 - 2);

  // 微信模拟支付 → 回调（重复回调幂等）
  const pay = await okc('POST', `/api/app/orders/${order.id}/pay`, { channel: 'wechat' }, U);
  assert.equal(pay.paid, false);
  await okc('POST', `/api/pay/mock/${pay.pay_no}/confirm`);
  assert.equal((await okc('POST', `/api/pay/mock/${pay.pay_no}/confirm`)).idempotent, true);
  let o = await okc('GET', `/api/app/orders/${order.id}`, null, U);
  assert.equal(o.status, 20);
  assert.equal(o.commission_status, 0);

  // 后台发货 → 用户收货（冷静期 0 天 → 立即入账）
  await okc('POST', `/api/admin/orders/${order.id}/ship`, { express_company: '顺丰', express_no: 'SF123' }, A);
  await okc('POST', `/api/app/orders/${order.id}/confirm`, {}, U);
  o = await okc('GET', `/api/app/orders/${order.id}`, null, U);
  assert.equal(o.status, 40);
  assert.equal(o.commission_status, 2);

  const dp = await okc('GET', '/api/app/debt-points', null, U);
  assert.equal(dp.summary.available, pv.dp_amount);
  assert.equal(dp.summary.cash_backed, expectCommission);

  // 清算 → 受理 → 划付 → 核销
  const debts = await okc('GET', '/api/app/debts', null, U);
  assert.equal(debts.length, 0, '新用户默认没有账单');
  // 银行：手机号查询 → 授权导入
  assert.equal((await call('POST', '/api/app/bank/query', { mobile: '13800001001', code: '123456' }, U)).code, 40001, '未同意授权书');
  const bq = await okc('POST', '/api/app/bank/query', { mobile: '13800001001', code: '123456', consent: true }, U);
  assert.equal(bq.bills.length, 3);
  await okc('POST', '/api/app/bank/import', { account_ids: bq.bills.map((b) => b.id) }, U);
  const debts2 = await okc('GET', '/api/app/debts', null, U);
  assert.equal(debts2.length, 3);
  assert.ok((await okc('GET', '/api/app/bank/letters', null, U)).length >= 3);
  const cmb = debts2.find((d) => d.creditor.startsWith('招商'));
  const cl = await okc('POST', '/api/app/clearances', { case_id: cmb.id }, U);
  assert.equal(cl.points, pv.dp_amount);
  assert.equal(cl.cash_remitted, expectCommission);
  assert.equal((await call('POST', '/api/app/clearances', { case_id: cmb.id }, U)).code, 40901, '处理中不可重复提交');
  await okc('POST', `/api/admin/clearances/${cl.id}/accept`, {}, A);
  await okc('POST', `/api/admin/clearances/${cl.id}/remit`, {}, A);
  const done = await okc('POST', `/api/admin/clearances/${cl.id}/write-off`, {}, A);
  assert.equal(done.status, 50);
  const after = (await okc('GET', '/api/app/debts', null, U)).find((d) => d.id === cmb.id);
  assert.equal(after.outstanding, Math.round((48500 - pv.dp_amount) * 100) / 100);
  assert.ok((await okc('GET', '/api/app/bank/letters', null, U)).some((l) => l.kind === 'partial'));
  assert.equal((await okc('GET', '/api/app/me', null, U)).credit_score, 615);

  // 复式记账平衡
  const led = await okc('GET', '/api/admin/ledger', null, A);
  assert.ok(led.check.balanced, `D=${led.check.d} C=${led.check.c}`);
});

test('钱包支付 + 退款：库存回滚、佣金失效', async () => {
  const { list } = await okc('GET', '/api/app/products?keyword=美式');
  const p = list.find((x) => x.price < 20);
  const me0 = await okc('GET', '/api/app/me', null, U);
  const o = await okc('POST', '/api/app/orders', { items: [{ product_id: p.id, qty: 1 }] }, U);
  assert.equal(o.freight_amount, 6, '不满 59 收运费');
  await okc('POST', `/api/app/orders/${o.id}/pay`, { channel: 'wallet' }, U);
  assert.equal((await okc('GET', '/api/app/me', null, U)).wallet_balance, Math.round((me0.wallet_balance - o.pay_amount) * 100) / 100);
  await okc('POST', `/api/app/orders/${o.id}/refund`, { reason: '不想要了' }, U);
  const rf = await okc('POST', `/api/admin/orders/${o.id}/refund-review`, { approve: true }, A);
  assert.equal(rf.status, 70);
  assert.equal(rf.commission_status, 9);
  assert.equal((await okc('GET', '/api/app/me', null, U)).wallet_balance, me0.wallet_balance);
  assert.equal((await okc('GET', `/api/app/products/${p.id}`)).stock, p.stock);
});

test('库存不足 / 余额不足 / 取消', async () => {
  const { list } = await okc('GET', '/api/app/products?keyword=神仙水');
  const p = list[0];
  await okc('PUT', `/api/admin/products/${p.id}`, { stock: 3 }, A);
  assert.equal((await call('POST', '/api/app/orders', { items: [{ product_id: p.id, qty: 4 }] }, U)).code, 50302);
  await okc('PUT', `/api/admin/products/${p.id}`, { stock: p.stock }, A);
  const o = await okc('POST', '/api/app/orders', { items: [{ product_id: p.id, qty: 5 }] }, U);
  assert.equal((await call('POST', `/api/app/orders/${o.id}/pay`, { channel: 'wallet' }, U)).code, 50301);
  assert.equal((await okc('POST', `/api/app/orders/${o.id}/cancel`, {}, U)).status, 50);
  assert.equal((await okc('GET', `/api/app/products/${p.id}`)).stock, p.stock);
});

test('后台：倍率规则修改即时影响报价；清算退回返还积分', async () => {
  const rules = await okc('GET', '/api/admin/offset-rules', null, A);
  const cap = rules.find((r) => r.rule_type === 'global_cap');
  await okc('PUT', `/api/admin/offset-rules/${cap.id}`, { value: 2 }, A);
  const { list } = await okc('GET', '/api/app/products?keyword=双人火锅');
  const q = await okc('POST', '/api/app/quote', { product_ids: [list[0].id] }, U);
  assert.equal(q[list[0].id].multiplier, 2);
  await okc('PUT', `/api/admin/offset-rules/${cap.id}`, { value: 6 }, A);

  const users = await okc('GET', '/api/admin/users?keyword=U1001', null, A);
  await okc('POST', `/api/admin/users/${users[0].id}/grant-dp`, { points: 50, cash_backed: 50, reason: '测试补发' }, A);
  const before = (await okc('GET', '/api/app/debt-points', null, U)).summary.available;
  const debt = (await okc('GET', '/api/app/debts', null, U)).find((d) => d.creditor.startsWith('招联'));
  assert.ok(debt);
  const cl = await okc('POST', '/api/app/clearances', { case_id: debt.id, points: 20 }, U);
  assert.equal((await okc('GET', '/api/app/debt-points', null, U)).summary.available, Math.round((before - 20) * 100) / 100);
  await okc('POST', `/api/admin/clearances/${cl.id}/reject`, { reason: '资料不全' }, A);
  assert.equal((await okc('GET', '/api/app/debt-points', null, U)).summary.available, before);

  const dash = await okc('GET', '/api/admin/dashboard', null, A);
  assert.ok(dash.total.orders >= 1);
});

test('偿清：账单余额归零 → 银行偿清回函 + 偿清证明 + 信用分 +15', async () => {
  const U2 = (await okc('POST', '/api/app/auth/demo-login', { ext_id: 'U1002' })).token;
  const d = (await okc('GET', '/api/app/debts', null, U2))[0];
  assert.equal(d.outstanding, 1800);
  const score0 = (await okc('GET', '/api/app/me', null, U2)).credit_score;
  const cl = await okc('POST', '/api/app/clearances', { case_id: d.id }, U2);
  assert.equal(cl.points, 1800);
  for (const a of ['accept', 'remit', 'write-off']) await okc('POST', `/api/admin/clearances/${cl.id}/${a}`, {}, A);
  const certs = await okc('GET', '/api/app/certificates', null, U2);
  assert.equal(certs.length, 1);
  assert.match(certs[0].cert_no, /^XGQC-MSXF-/);
  assert.ok((await okc('GET', '/api/app/bank/letters', null, U2)).some((l) => l.kind === 'settled'));
  assert.equal((await okc('GET', '/api/app/me', null, U2)).credit_score, score0 + 3 + 15);
  const ov = await okc('GET', '/api/app/overview', null, U2);
  assert.equal(ov.bills.settled, 1);
  assert.equal(ov.certificates, 1);
});

test('任意手机号可模拟查询银行账单，且结果稳定', async () => {
  const a = await okc('POST', '/api/app/bank/query', { mobile: '13912345678', code: '123456', consent: true }, U);
  const b = await okc('POST', '/api/app/bank/query', { mobile: '13912345678', code: '123456', consent: true }, U);
  assert.ok(a.bills.length >= 1 && a.bills.length <= 3);
  assert.deepEqual(a.bills.map((x) => x.amount), b.bills.map((x) => x.amount));
});
