/**
 * 合作银行模拟网关
 * - 按手机号查询名下待清偿账单（模拟征信/银行开放接口，需短信验证 + 授权）
 * - 授权导入为平台「待清偿账单」
 * - 清偿各环节银行回函；账单偿清后出具《偿清证明》
 * 生产环境替换为银行开放平台 / 征信授权查询接口即可，对外接口保持不变。
 */
import crypto from 'node:crypto';
import { all, bizNo, nowIso, one, r2, run, tx } from '../db.js';
import { E } from '../errors.js';
import { notify } from './finance.js';

export const BANKS = [
  { code: 'CMB', name: '招商银行', color: '#C8102E', short: '招' },
  { code: 'ICBC', name: '中国工商银行', color: '#C7000B', short: '工' },
  { code: 'CCB', name: '中国建设银行', color: '#0066B3', short: '建' },
  { code: 'BOC', name: '中国银行', color: '#B81C22', short: '中' },
  { code: 'ABC', name: '中国农业银行', color: '#00936F', short: '农' },
  { code: 'BCOM', name: '交通银行', color: '#1D3E8A', short: '交' },
  { code: 'SPDB', name: '浦发银行', color: '#0B3B8C', short: '浦' },
  { code: 'CITIC', name: '中信银行', color: '#D0021B', short: '信' },
  { code: 'CMBC', name: '民生银行', color: '#00A0E9', short: '民' },
  { code: 'PAB', name: '平安银行', color: '#F05A22', short: '平' },
  { code: 'MSXF', name: '马上消费金融', color: '#FF6A00', short: '马' },
  { code: 'ZLXF', name: '招联消费金融', color: '#E60012', short: '联' },
];
export const bankByCode = (c) => BANKS.find((b) => b.code === c);
export const bankByName = (n) => BANKS.find((b) => n && n.startsWith(b.name));

const PRODUCTS = [
  ['信用卡', 3000, 60000],
  ['信用卡', 2000, 40000],
  ['消费贷', 5000, 80000],
  ['经营贷', 20000, 150000],
];

/** 由手机号确定性地生成银行侧账单（同一手机号每次查询结果一致，便于演示） */
function synthesize(mobile) {
  const h = crypto.createHash('sha256').update(`xg-bank:${mobile}`).digest();
  const n = 1 + (h[0] % 3); // 1~3 家机构
  const used = new Set();
  const out = [];
  for (let i = 0; i < n; i++) {
    let bi = h[1 + i] % BANKS.length;
    while (used.has(bi)) bi = (bi + 1) % BANKS.length;
    used.add(bi);
    const bank = BANKS[bi];
    const [product, lo, hi] = PRODUCTS[h[5 + i] % PRODUCTS.length];
    const principal = Math.round((lo + ((h[8 + i] * 256 + h[9 + i]) / 65535) * (hi - lo)) / 100) * 100;
    const interest = r2(principal * (0.02 + (h[12 + i] % 6) / 100));
    const overdue = [0, 0, 15, 32, 61, 95][h[16 + i] % 6];
    out.push({ bank, product, principal, interest, overdue, account: `${bank.code}-${product === '信用卡' ? 'CC' : 'LN'}-${mobile.slice(-4)}${String(h[20 + i]).padStart(3, '0')}` });
  }
  return out;
}

/** 查询：返回银行侧账单（已导入的标记 imported），并缓存到 bank_accounts */
export function queryBills(mobile) {
  if (!/^1\d{10}$/.test(mobile)) throw E.bad('请输入正确的 11 位手机号');
  if (!one('SELECT id FROM bank_accounts WHERE mobile = ? LIMIT 1', mobile)) {
    for (const x of synthesize(mobile)) {
      run('INSERT OR IGNORE INTO bank_accounts (mobile, bank_code, bank_name, product, account_no, principal, interest, overdue_days) VALUES (?,?,?,?,?,?,?,?)', mobile, x.bank.code, x.bank.name, x.product, x.account, x.principal, x.interest, x.overdue);
    }
  }
  const rows = all('SELECT * FROM bank_accounts WHERE mobile = ? ORDER BY principal DESC', mobile);
  return {
    mobile: mobile.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2'),
    query_no: bizNo('BQ'),
    queried_at: nowIso(),
    total: r2(rows.reduce((a, x) => a + x.principal + x.interest, 0)),
    bills: rows.map((x) => ({ ...x, amount: r2(x.principal + x.interest), bank: bankByCode(x.bank_code), imported: !!x.imported_case_id })),
  };
}

/** 授权导入：把选中的银行账单导入为平台待清偿账单 */
export function importBills(userId, mobile, accountIds) {
  return tx(() => {
    const ids = (accountIds || []).map(Number);
    if (!ids.length) throw E.bad('请选择要导入的账单');
    const imported = [];
    for (const id of ids) {
      const a = one('SELECT * FROM bank_accounts WHERE id = ? AND mobile = ?', id, mobile);
      if (!a) throw E.notFound('账单不存在');
      if (a.imported_case_id) continue;
      const amt = r2(a.principal + a.interest);
      const r = run("INSERT INTO debt_cases (user_id, creditor, case_no, debt_type, principal, outstanding, bank_code, source, created_at) VALUES (?,?,?,?,?,?,?,'bank_api',?)", userId, `${a.bank_name}${a.product === '信用卡' ? '信用卡中心' : ''}`, a.account_no, a.product, amt, amt, a.bank_code, nowIso());
      const caseId = Number(r.lastInsertRowid);
      run('UPDATE bank_accounts SET imported_case_id = ? WHERE id = ?', caseId, a.id);
      imported.push(caseId);
      letter(userId, caseId, a.bank_name, 'accepted', '账单接入确认函', `尊敬的客户：您授权的 ${a.product}账单（${a.account_no}，待清偿 ¥${amt.toFixed(2)}）已接入星光云清偿通道。此后您在平台获得的清偿金可直接用于清偿本账单，我行将按清偿金面值逐笔核减并出具回执。`);
    }
    if (imported.length) notify(userId, '银行账单已接入', `${imported.length} 笔账单已接入清偿通道，购物返还的清偿金可直接用于清偿。`);
    return { imported: imported.length, case_ids: imported };
  });
}

export function letter(userId, caseId, bankName, kind, title, body) {
  const ref = bizNo('BL');
  run('INSERT INTO bank_letters (user_id, case_id, bank_name, kind, title, body, ref_no, created_at) VALUES (?,?,?,?,?,?,?,?)', userId, caseId, bankName, kind, title, body, ref, nowIso());
  return ref;
}

/** 账单余额归零：银行签发偿清证明 + 偿清回函 */
export function issueCertificate(caseId, issuedBy = '系统自动') {
  const c = one('SELECT * FROM debt_cases WHERE id = ?', caseId);
  if (!c || c.outstanding > 0.005) return null;
  const exists = one('SELECT * FROM certificates WHERE case_id = ?', caseId);
  if (exists) return exists;
  const bank = bankByCode(c.bank_code) || bankByName(c.creditor);
  const year = new Date().getFullYear();
  const certNo = `XGQC-${bank?.code || 'BANK'}-${year}-${String(caseId).padStart(6, '0')}`;
  const sig = `SM2:${crypto.createHash('sha256').update(`${certNo}|${c.case_no}|${c.principal}`).digest('hex').slice(0, 32)}`;
  const at = nowIso();
  run('INSERT INTO certificates (cert_no, user_id, case_id, bank_name, case_no, principal, cash_paid, reduction, signature, issued_by, issued_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', certNo, c.user_id, c.id, c.creditor, c.case_no, c.principal, r2(c.cash_paid), r2(c.principal - c.cash_paid), sig, issuedBy, at);
  run('UPDATE debt_cases SET status = 3, settled_at = ? WHERE id = ?', at, c.id);
  run('UPDATE users SET credit_score = credit_score + 15 WHERE id = ?', c.user_id);
  letter(c.user_id, c.id, c.creditor, 'settled', '账单偿清确认函', `尊敬的客户：经核对，您名下账单（${c.case_no}）原待清偿金额 ¥${c.principal.toFixed(2)} 已全部偿清，账户已结清，无剩余应还款项。我行已出具《偿清证明》（编号 ${certNo}），并将于下一个报送周期向征信系统更新结清状态。感谢您的信任，祝生活愉快。`);
  notify(c.user_id, '恭喜，账单已偿清', `${c.creditor} 已出具《偿清证明》${certNo}，信用分 +15。`);
  return one('SELECT * FROM certificates WHERE case_id = ?', caseId);
}
