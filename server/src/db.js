import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(__dirname, '..');
export const DATA_DIR = process.env.DATA_DIR || path.join(ROOT, 'data');
fs.mkdirSync(DATA_DIR, { recursive: true });
export const DB_FILE = process.env.DB_FILE || path.join(DATA_DIR, 'xinguang.db');

export const db = new DatabaseSync(DB_FILE);
db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 5000;');

/** 金额统一保留两位小数（避免浮点尾差） */
export const r2 = (v) => Math.round((Number(v) + Number.EPSILON) * 100) / 100;
export const nowIso = () => new Date().toISOString();

let txDepth = 0;
/** 同步事务：支持嵌套（内层直接执行），抛错整体回滚 */
export function tx(fn) {
  if (txDepth > 0) return fn();
  txDepth++;
  db.exec('BEGIN IMMEDIATE');
  try {
    const out = fn();
    db.exec('COMMIT');
    return out;
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  } finally {
    txDepth--;
  }
}

export const one = (sql, ...p) => db.prepare(sql).get(...p);
export const all = (sql, ...p) => db.prepare(sql).all(...p);
export const run = (sql, ...p) => db.prepare(sql).run(...p);

/** 生成业务单号：前缀 + yyyyMMddHHmmss + 4 位随机 */
export function bizNo(prefix) {
  const d = new Date();
  const p = (n, l = 2) => String(n).padStart(l, '0');
  return `${prefix}${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}${p(Math.floor(Math.random() * 10000), 4)}`;
}

export function getSetting(key, def) {
  const row = one('SELECT value FROM settings WHERE key = ?', key);
  if (!row) return def;
  const n = Number(row.value);
  return typeof def === 'number' && !Number.isNaN(n) ? n : row.value;
}

export function migrate() {
  db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  ext_id        TEXT UNIQUE,                 -- 对应 App 内演示身份 U1001 等
  mobile        TEXT UNIQUE NOT NULL,
  nickname      TEXT NOT NULL,
  credit_score  INTEGER NOT NULL DEFAULT 600,
  wallet_balance REAL NOT NULL DEFAULT 0,
  status        INTEGER NOT NULL DEFAULT 1,  -- 1 正常 2 冻结
  created_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS admins (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name          TEXT NOT NULL,
  created_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS categories (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT UNIQUE NOT NULL,
  icon       TEXT NOT NULL DEFAULT '🛍️',
  image      TEXT,
  sort       INTEGER NOT NULL DEFAULT 0,
  status     INTEGER NOT NULL DEFAULT 1,     -- 1 启用 0 停用
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id     INTEGER NOT NULL REFERENCES categories(id),
  name            TEXT NOT NULL,
  subtitle        TEXT NOT NULL DEFAULT '',
  description     TEXT NOT NULL DEFAULT '',
  merchant        TEXT NOT NULL DEFAULT '新光云自营',
  image           TEXT,
  emoji           TEXT NOT NULL DEFAULT '🛍️',
  price           REAL NOT NULL,
  original_price  REAL,
  commission_rate REAL NOT NULL DEFAULT 10,  -- 平台佣金率 %（= 平台利润 / 售价）
  stock           INTEGER NOT NULL DEFAULT 0,
  sales           INTEGER NOT NULL DEFAULT 0,
  sort            INTEGER NOT NULL DEFAULT 0,
  status          INTEGER NOT NULL DEFAULT 1, -- 1 上架 0 下架
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_products_cat ON products(category_id, status);

-- 平债倍率规则：category 品类基础倍率 / credit_tier 信用加成 / global_cap 全局上限
CREATE TABLE IF NOT EXISTS offset_rules (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  code        TEXT UNIQUE NOT NULL,
  rule_type   TEXT NOT NULL CHECK (rule_type IN ('category','credit_tier','global_cap')),
  name        TEXT NOT NULL,
  category_id INTEGER REFERENCES categories(id),
  credit_min  INTEGER,
  credit_max  INTEGER,
  value       REAL NOT NULL,
  status      INTEGER NOT NULL DEFAULT 0,    -- 0 草稿 1 灰度 2 生产 3 关闭
  hit_count   INTEGER NOT NULL DEFAULT 0,
  approved_by TEXT,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  label TEXT
);

CREATE TABLE IF NOT EXISTS addresses (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id),
  name       TEXT NOT NULL,
  phone      TEXT NOT NULL,
  region     TEXT NOT NULL,
  detail     TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS cart_items (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id),
  product_id INTEGER NOT NULL REFERENCES products(id),
  qty        INTEGER NOT NULL DEFAULT 1,
  checked    INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  UNIQUE(user_id, product_id)
);

-- 订单状态：10 待支付 20 待发货 30 已发货 40 已完成 50 已取消 60 退款中 70 已退款
CREATE TABLE IF NOT EXISTS orders (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  order_no          TEXT UNIQUE NOT NULL,
  user_id           INTEGER NOT NULL REFERENCES users(id),
  status            INTEGER NOT NULL DEFAULT 10,
  goods_amount      REAL NOT NULL,
  freight_amount    REAL NOT NULL DEFAULT 0,
  pay_amount        REAL NOT NULL,
  commission_amount REAL NOT NULL,            -- 平台佣金（= 现金背书）
  dp_amount         REAL NOT NULL,            -- 预计/实际发放债务积分
  address_json      TEXT,
  remark            TEXT,
  pay_channel       TEXT,
  paid_at           TEXT,
  shipped_at        TEXT,
  express_company   TEXT,
  express_no        TEXT,
  completed_at      TEXT,
  cancelled_at      TEXT,
  cancel_reason     TEXT,
  refund_reason     TEXT,
  refund_reject_reason TEXT,
  refunded_at       TEXT,
  pre_refund_status INTEGER,
  expire_at         TEXT NOT NULL,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id, status);

CREATE TABLE IF NOT EXISTS order_items (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id        INTEGER NOT NULL REFERENCES orders(id),
  product_id      INTEGER NOT NULL REFERENCES products(id),
  category_id     INTEGER NOT NULL,
  name            TEXT NOT NULL,
  image           TEXT,
  emoji           TEXT,
  price           REAL NOT NULL,
  qty             INTEGER NOT NULL,
  subtotal        REAL NOT NULL,
  commission_rate REAL NOT NULL,
  commission      REAL NOT NULL,
  multiplier      REAL NOT NULL,
  dp_amount       REAL NOT NULL,
  rule_snapshot   TEXT
);

CREATE TABLE IF NOT EXISTS payments (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  pay_no     TEXT UNIQUE NOT NULL,
  order_id   INTEGER NOT NULL REFERENCES orders(id),
  user_id    INTEGER NOT NULL,
  channel    TEXT NOT NULL,                    -- wallet / wechat / alipay
  amount     REAL NOT NULL,
  status     INTEGER NOT NULL DEFAULT 0,       -- 0 待支付 1 成功 2 关闭 3 已退款
  trade_no   TEXT,
  created_at TEXT NOT NULL,
  paid_at    TEXT
);

-- 佣金单：0 预估(已支付，待确认收货) 1 待结算(已收货，冷静期) 2 已入账(转为债务积分) 9 已失效(退款)
CREATE TABLE IF NOT EXISTS commissions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL REFERENCES users(id),
  order_id    INTEGER NOT NULL UNIQUE REFERENCES orders(id),
  commission  REAL NOT NULL,
  dp_amount   REAL NOT NULL,
  status      INTEGER NOT NULL DEFAULT 0,
  settle_at   TEXT,
  settled_at  TEXT,
  dp_batch_id INTEGER,
  created_at  TEXT NOT NULL
);

-- 债务积分批次：1 DP = ¥1 债务抵扣面值；cash_backed = 平台真实持有现金
CREATE TABLE IF NOT EXISTS dp_batches (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL REFERENCES users(id),
  source      TEXT NOT NULL,                   -- consumption / admin_grant
  face_value  REAL NOT NULL,
  cash_backed REAL NOT NULL,
  consumed    REAL NOT NULL DEFAULT 0,
  ref_type    TEXT,
  ref_id      INTEGER,
  title       TEXT NOT NULL,
  created_at  TEXT NOT NULL
);

-- 用户债务（债权方案件）：1 还款中 3 已结清
CREATE TABLE IF NOT EXISTS debt_cases (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL REFERENCES users(id),
  creditor    TEXT NOT NULL,
  case_no     TEXT NOT NULL,
  debt_type   TEXT NOT NULL DEFAULT '信用卡',
  principal   REAL NOT NULL,
  outstanding REAL NOT NULL,
  cleared     REAL NOT NULL DEFAULT 0,
  status      INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL
);

-- 清算单：10 已提交 20 已受理 30 资金已划付 50 已核销 90 已退回
CREATE TABLE IF NOT EXISTS clearances (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  clearance_no   TEXT UNIQUE NOT NULL,
  user_id        INTEGER NOT NULL REFERENCES users(id),
  case_id        INTEGER NOT NULL REFERENCES debt_cases(id),
  points         REAL NOT NULL,
  cash_remitted  REAL NOT NULL,
  reduction      REAL NOT NULL,
  consumed_json  TEXT NOT NULL,                -- {batchId: amount}
  status         INTEGER NOT NULL DEFAULT 10,
  bank_ref       TEXT,
  reject_reason  TEXT,
  history_json   TEXT NOT NULL DEFAULT '[]',
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS wallet_txs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id),
  type       TEXT NOT NULL,
  title      TEXT NOT NULL,
  amount     REAL NOT NULL,
  balance_after REAL NOT NULL,
  ref        TEXT,
  created_at TEXT NOT NULL
);

-- 复式记账分录
CREATE TABLE IF NOT EXISTS ledger (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  tx_no      TEXT NOT NULL,
  account    TEXT NOT NULL,
  direction  TEXT NOT NULL CHECK (direction IN ('D','C')),
  amount     REAL NOT NULL,
  biz_type   TEXT NOT NULL,
  biz_ref    TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ledger_ref ON ledger(biz_ref);

CREATE TABLE IF NOT EXISTS notifications (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id),
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  read       INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

-- 偿清证明（银行出具，账单余额归零时签发）
CREATE TABLE IF NOT EXISTS certificates (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  cert_no     TEXT UNIQUE NOT NULL,
  user_id     INTEGER NOT NULL REFERENCES users(id),
  case_id     INTEGER NOT NULL UNIQUE REFERENCES debt_cases(id),
  bank_name   TEXT NOT NULL,
  case_no     TEXT NOT NULL,
  principal   REAL NOT NULL,
  cash_paid   REAL NOT NULL,
  reduction   REAL NOT NULL,
  signature   TEXT NOT NULL,
  issued_by   TEXT NOT NULL,
  issued_at   TEXT NOT NULL
);

-- 银行回函：受理 / 部分清偿 / 偿清
CREATE TABLE IF NOT EXISTS bank_letters (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL REFERENCES users(id),
  case_id     INTEGER REFERENCES debt_cases(id),
  bank_name   TEXT NOT NULL,
  kind        TEXT NOT NULL,                  -- accepted / partial / settled
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  ref_no      TEXT NOT NULL,
  read        INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL
);

-- 银行侧模拟账单库（按手机号查询，授权后导入为待清偿账单）
CREATE TABLE IF NOT EXISTS bank_accounts (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  mobile      TEXT NOT NULL,
  bank_code   TEXT NOT NULL,
  bank_name   TEXT NOT NULL,
  product     TEXT NOT NULL,                  -- 信用卡 / 消费贷 / 经营贷
  account_no  TEXT NOT NULL,
  principal   REAL NOT NULL,
  interest    REAL NOT NULL DEFAULT 0,
  overdue_days INTEGER NOT NULL DEFAULT 0,
  imported_case_id INTEGER,
  UNIQUE(mobile, account_no)
);

-- ───────── 微劳动 ─────────
-- 任务：0 草稿 1 审核中 2 招募中 3 已满员 4 已结束 6 已下架 8 审核驳回
CREATE TABLE IF NOT EXISTS tasks (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  task_no          TEXT UNIQUE NOT NULL,
  publisher_id     INTEGER NOT NULL REFERENCES users(id),
  publisher_name   TEXT NOT NULL,
  task_type        TEXT NOT NULL,             -- content/survey/visit/service/promo/skill/label/errand
  title            TEXT NOT NULL,
  description      TEXT NOT NULL,
  requirements     TEXT NOT NULL DEFAULT '[]', -- JSON 交付要求清单
  image            TEXT,
  reward           REAL NOT NULL,             -- 单份报酬
  cash_pct         REAL NOT NULL DEFAULT 40,  -- 现金占比（扣服务费后）
  clear_pct        REAL NOT NULL DEFAULT 60,  -- 清偿金占比
  fee_pct          REAL NOT NULL DEFAULT 10,  -- 平台服务费
  boost            INTEGER NOT NULL DEFAULT 1,-- 清偿金部分是否享受信用加成
  quota            INTEGER NOT NULL,
  taken            INTEGER NOT NULL DEFAULT 0,
  done             INTEGER NOT NULL DEFAULT 0,
  kyc_required     INTEGER NOT NULL DEFAULT 1,
  credit_min       INTEGER NOT NULL DEFAULT 0,
  duration_hours   INTEGER NOT NULL DEFAULT 72, -- 接单后交付时限
  review_hours     INTEGER NOT NULL DEFAULT 72, -- 商家验收时限，超时自动通过
  tags             TEXT NOT NULL DEFAULT '[]',
  city             TEXT,
  deposit          REAL NOT NULL,             -- 托管押金 = reward × quota
  deposit_left     REAL NOT NULL,
  status           INTEGER NOT NULL DEFAULT 1,
  reject_reason    TEXT,
  deadline_at      TEXT NOT NULL,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status, task_type);

-- 任务单：10 已接单 20 进行中 40 已提交(AI 初审中) 45 AI 初审未过(可重交) 50 待验收 55 申诉中 60 已通过 70 已驳回 80 已结算 31 超时 32 已放弃
CREATE TABLE IF NOT EXISTS task_orders (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  order_no        TEXT UNIQUE NOT NULL,
  task_id         INTEGER NOT NULL REFERENCES tasks(id),
  user_id         INTEGER NOT NULL REFERENCES users(id),
  status          INTEGER NOT NULL DEFAULT 20,
  submission_text TEXT,
  submission_link TEXT,
  submission_files TEXT NOT NULL DEFAULT '[]',
  ai_score        REAL,
  ai_report       TEXT,
  ai_attempts     INTEGER NOT NULL DEFAULT 0,
  review_note     TEXT,
  dispute_reason  TEXT,
  arbitration     TEXT,
  gross           REAL,
  fee             REAL,
  cash_amount     REAL,
  clear_cash      REAL,                       -- 清偿部分对应的现金背书
  clear_amount    REAL,                       -- 发放的清偿金面值（可含信用加成）
  multiplier      REAL,
  rating          INTEGER,
  history_json    TEXT NOT NULL DEFAULT '[]',
  due_at          TEXT NOT NULL,
  submitted_at    TEXT,
  review_due_at   TEXT,
  settled_at      TEXT,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_task_orders_user ON task_orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_task_orders_task ON task_orders(task_id, status);

-- ───────── 内容社区 ─────────
-- 审核：0 待审 1 已发布 2 精选 9 已拦截
CREATE TABLE IF NOT EXISTS posts (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id       INTEGER NOT NULL REFERENCES users(id),
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  images        TEXT NOT NULL DEFAULT '[]',
  tags          TEXT NOT NULL DEFAULT '[]',
  task_order_id INTEGER,
  ai_generated  INTEGER NOT NULL DEFAULT 0,
  status        INTEGER NOT NULL DEFAULT 0,
  ai_score      REAL,
  block_reason  TEXT,
  views         INTEGER NOT NULL DEFAULT 0,
  likes         INTEGER NOT NULL DEFAULT 0,
  comments      INTEGER NOT NULL DEFAULT 0,
  revenue       REAL NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS post_likes (post_id INTEGER NOT NULL, user_id INTEGER NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY (post_id, user_id));
CREATE TABLE IF NOT EXISTS post_comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT, post_id INTEGER NOT NULL, user_id INTEGER NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL
);

-- ───────── 实名 / 提现 ─────────
CREATE TABLE IF NOT EXISTS kyc (
  user_id     INTEGER PRIMARY KEY REFERENCES users(id),
  level       INTEGER NOT NULL DEFAULT 1,     -- 1 手机 2 实名 3 活体 4 银行卡
  real_name   TEXT,
  id_no_mask  TEXT,
  bank_name   TEXT,
  card_mask   TEXT,
  pay_pwd     TEXT,
  updated_at  TEXT NOT NULL
);
-- 提现：10 审核中 20 打款中 30 已到账 90 已驳回
CREATE TABLE IF NOT EXISTS withdrawals (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  withdraw_no  TEXT UNIQUE NOT NULL,
  user_id      INTEGER NOT NULL REFERENCES users(id),
  amount       REAL NOT NULL,
  fee          REAL NOT NULL DEFAULT 0,
  bank_name    TEXT NOT NULL,
  card_mask    TEXT NOT NULL,
  status       INTEGER NOT NULL DEFAULT 10,
  risk_score   REAL NOT NULL DEFAULT 0,
  risk_hits    TEXT NOT NULL DEFAULT '[]',
  reject_reason TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

-- ───────── 风控 ─────────
CREATE TABLE IF NOT EXISTS risk_rules (
  code        TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  scene       TEXT NOT NULL,                  -- withdraw/task/content/pay
  description TEXT NOT NULL,
  score       INTEGER NOT NULL,
  action      TEXT NOT NULL,                  -- pass/review/block
  threshold   REAL,
  enabled     INTEGER NOT NULL DEFAULT 1,
  hits        INTEGER NOT NULL DEFAULT 0
);
-- 风险案件：0 待处置 1 已放行 2 已拦截 3 已冻结
CREATE TABLE IF NOT EXISTS risk_cases (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL,
  rule_code   TEXT NOT NULL,
  scene       TEXT NOT NULL,
  ref_type    TEXT,
  ref_id      INTEGER,
  score       INTEGER NOT NULL,
  detail      TEXT NOT NULL,
  status      INTEGER NOT NULL DEFAULT 0,
  handled_by  TEXT,
  note        TEXT,
  created_at  TEXT NOT NULL,
  handled_at  TEXT
);

-- ───────── AI 对话 ─────────
CREATE TABLE IF NOT EXISTS ai_messages (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL,
  agent      TEXT NOT NULL,
  role       TEXT NOT NULL,
  content    TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS admin_logs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  admin      TEXT NOT NULL,
  action     TEXT NOT NULL,
  target     TEXT,
  detail     TEXT,
  created_at TEXT NOT NULL
);
`);
  // 增量列（老库升级）
  const addCol = (t, c, def) => {
    if (!all(`PRAGMA table_info(${t})`).some((x) => x.name === c)) db.exec(`ALTER TABLE ${t} ADD COLUMN ${c} ${def}`);
  };
  addCol('categories', 'parent_id', 'INTEGER');
  addCol('categories', 'slug', 'TEXT');
  addCol('debt_cases', 'bank_code', 'TEXT');
  addCol('debt_cases', 'source', "TEXT NOT NULL DEFAULT 'manual'");
  addCol('debt_cases', 'cash_paid', 'REAL NOT NULL DEFAULT 0');
  addCol('debt_cases', 'settled_at', 'TEXT');
  addCol('users', 'role', "TEXT NOT NULL DEFAULT 'user'"); // user / merchant / bank / risk / ops
  addCol('users', 'org_name', 'TEXT');
  addCol('users', 'bank_code', 'TEXT');                     // 银行专员所属银行（数据隔离）
  addCol('users', 'wallet_frozen', 'REAL NOT NULL DEFAULT 0');
  addCol('users', 'skills', "TEXT NOT NULL DEFAULT '[]'");
  addCol('users', 'city', 'TEXT');
  addCol('users', 'labor_level', 'INTEGER NOT NULL DEFAULT 1');
}
