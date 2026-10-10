import { one, nowIso, r2, run, tx } from './db.js';
import { hashPassword } from './auth.js';
import { CATEGORIES, CATEGORY_MULTIPLIER, PRODUCTS, SUBS } from './catalog.js';

const SETTINGS = [
  ['default_multiplier', '1', '品类无倍率规则时的默认返还倍率'],
  ['commission_settle_days', '7', '确认收货后的售后保障期（天），到期清偿金自动到账；0 = 立即到账'],
  ['auto_confirm_days', '10', '发货后自动确认收货（天）'],
  ['order_expire_minutes', '30', '待支付订单超时关闭（分钟）'],
  ['free_freight_threshold', '59', '满额包邮（元）'],
  ['freight_fee', '6', '不满额运费（元）'],
  ['min_clear_points', '10', '单次清偿最低金额（元）'],
  ['task_fee_pct', '10', '微劳动平台服务费（%）'],
  ['task_max_active', '5', '每人同时进行的任务上限'],
  ['task_ai_max_attempts', '3', 'AI 初审最多提交次数'],
  ['task_auto_approve', '1', '新任务无敏感词时自动上架（1 是 0 否）'],
  ['withdraw_min', '10', '单笔最低提现（元）'],
  ['withdraw_auto_max', '500', '无风险命中时自动到账上限（元）'],
  ['withdraw_fee_pct', '0', '提现手续费（%）'],
  ['content_rev_per_like', '0.05', '内容激励：每个赞（元）'],
  ['content_cash_pct', '40', '内容激励：现金占比（%），其余为清偿金'],
];

// [code, 类型, 名称, 大类名, 信用下限, 信用上限, 值, 状态]
const RULES = [
  ...Object.entries(CATEGORY_MULTIPLIER).map(([cat, v], i) => [`OR-CAT-${String(i + 1).padStart(3, '0')}`, 'category', `${cat} · 基础倍率`, cat, null, null, v, 2]),
  ['OR-CR-001', 'credit_tier', '信用 550~599 · 无加成', null, 550, 599, 0, 2],
  ['OR-CR-002', 'credit_tier', '信用 600~649 · +0.5', null, 600, 649, 0.5, 2],
  ['OR-CR-003', 'credit_tier', '信用 650~699 · +1.0', null, 650, 699, 1.0, 2],
  ['OR-CR-004', 'credit_tier', '信用 700+ · +1.5', null, 700, 999, 1.5, 2],
  ['OR-CAP-001', 'global_cap', '全局倍率上限（财务风控红线）', null, null, null, 6, 2],
];

// 与 App 演示身份一一对应（ext_id）
const USERS = [
  ['U1001', '13800001001', '林晓明', 612, 1286.5],
  ['U1002', '13800001002', '苏雨桐', 688, 8620],
  ['U1003', '13800001003', '星辰品牌', 750, 128000],
  ['U1004', '13800001004', '陈锐', 600, 0],
  ['U1005', '13800001005', '周梦', 600, 0],
  ['U1006', '13800001006', '顾承业', 600, 0],
];

// 演示账号的预置银行账单（手机号查询时直接命中，其余手机号按规则模拟生成）
const BANK_SEED = [
  ['13800001001', 'CMB', '招商银行', '信用卡', 'CMB-CC-1001118', 46200, 2300, 96],
  ['13800001001', 'ZLXF', '招联消费金融', '消费贷', 'ZLXF-LN-1001077', 30000, 2000, 45],
  ['13800001001', 'PAB', '平安银行', '信用卡', 'PAB-CC-1001093', 18000, 860, 0],
  ['13800001002', 'BCOM', '交通银行', '信用卡', 'BCOM-CC-1002330', 35000, 2400, 12],
  ['13800001002', 'MSXF', '马上消费金融', '消费贷', 'MSXF-LN-1002088', 1800, 0, 0],
];

const rand = (a, b) => Math.floor(a + Math.random() * (b - a));

export function seed({ adminPassword } = {}) {
  return tx(() => {
    const at = nowIso();
    for (const [k, v, l] of SETTINGS) run('INSERT OR IGNORE INTO settings (key, value, label) VALUES (?,?,?)', k, v, l);

    let createdAdmin = null;
    if (!one('SELECT id FROM admins LIMIT 1')) {
      const pwd = adminPassword || process.env.ADMIN_PASSWORD || 'admin123';
      run('INSERT INTO admins (username, password_hash, name, created_at) VALUES (?,?,?,?)', 'admin', hashPassword(pwd), '超级管理员', at);
      createdAdmin = { username: 'admin', password: pwd };
    }

    if (one('SELECT id FROM categories LIMIT 1')) return { createdAdmin, seeded: false };

    // 大类 + 小类
    CATEGORIES.forEach((c, i) => {
      const r = run('INSERT INTO categories (name, icon, image, sort, status, slug, parent_id, created_at) VALUES (?,?,?,?,1,?,NULL,?)', c.name, c.icon, `/media/img/${c.slug}.webp`, i, c.slug, at);
      const pid = Number(r.lastInsertRowid);
      c.subs.forEach((s, j) => run('INSERT INTO categories (name, icon, image, sort, status, slug, parent_id, created_at) VALUES (?,?,?,?,1,?,?,?)', SUBS[s].name, SUBS[s].emoji, `/media/img/goods_${s}.webp`, j, s, pid, at));
    });
    const sub = (slug) => one('SELECT id, image, icon FROM categories WHERE slug = ?', slug);

    let sort = 0;
    for (const [slug, list] of Object.entries(PRODUCTS)) {
      const s = sub(slug);
      for (const [name, brand, spec, price, orig, rate, stock] of list) {
        run(
          'INSERT INTO products (category_id, name, subtitle, description, merchant, image, emoji, price, original_price, commission_rate, stock, sales, sort, status, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,1,?,?)',
          s.id, `${brand} ${name}`, spec, `【${brand}】${name}\n规格：${spec}\n\n· 正品保障，官方授权渠道供货\n· 确认收货后享 7 天售后保障，期满清偿金自动到账\n· 虚拟券类商品付款后即时发放，到店出示核销`, brand, s.image, s.icon, price, orig, rate, stock, rand(30, 5000), sort++, at, at,
        );
      }
    }

    // 倍率规则挂在大类上；小类商品按其父类匹配
    const top = (n) => one('SELECT id FROM categories WHERE name = ? AND parent_id IS NULL', n)?.id ?? null;
    for (const [code, type, name, cat, mn, mx, v, st] of RULES) {
      run('INSERT INTO offset_rules (code, rule_type, name, category_id, credit_min, credit_max, value, status, approved_by, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', code, type, name, cat ? top(cat) : null, mn, mx, v, st, 'COO', at, at);
    }

    for (const [ext, mobile, nick, credit, bal] of USERS) {
      const ur = run('INSERT INTO users (ext_id, mobile, nickname, credit_score, wallet_balance, created_at) VALUES (?,?,?,?,?,?)', ext, mobile, nick, credit, bal, at);
      if (bal > 0) run('INSERT INTO wallet_txs (user_id, type, title, amount, balance_after, created_at) VALUES (?,?,?,?,?,?)', Number(ur.lastInsertRowid), 'opening', '期初余额', bal, bal, at);
    }
    for (const b of BANK_SEED) {
      run('INSERT OR IGNORE INTO bank_accounts (mobile, bank_code, bank_name, product, account_no, principal, interest, overdue_days) VALUES (?,?,?,?,?,?,?,?)', ...b);
    }
    // 苏雨桐：预先导入 1 笔小额账单，用于演示「偿清 → 银行回函 → 偿清证明」
    const u2 = one("SELECT id FROM users WHERE ext_id = 'U1002'").id;
    const acc = one("SELECT * FROM bank_accounts WHERE account_no = 'MSXF-LN-1002088'");
    const cr = run("INSERT INTO debt_cases (user_id, creditor, case_no, debt_type, principal, outstanding, bank_code, source, created_at) VALUES (?,?,?,?,?,?,?,'bank_api',?)", u2, acc.bank_name, acc.account_no, acc.product, r2(acc.principal), r2(acc.principal), acc.bank_code, at);
    run('UPDATE bank_accounts SET imported_case_id = ? WHERE id = ?', Number(cr.lastInsertRowid), acc.id);
    run("INSERT INTO dp_batches (user_id, source, face_value, cash_backed, ref_type, title, created_at) VALUES (?, 'consumption', 1860, 372, 'seed', '购物返还 · 历史订单汇总', ?)", u2, at);
    return { createdAdmin, seeded: true };
  });
}
