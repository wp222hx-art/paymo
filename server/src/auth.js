import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { DATA_DIR, one } from './db.js';
import { E } from './errors.js';

/** 令牌签名密钥：优先环境变量，否则首次启动生成并持久化到 data/secret.key */
function loadSecret() {
  if (process.env.JWT_SECRET) return process.env.JWT_SECRET;
  const f = path.join(DATA_DIR, 'secret.key');
  if (fs.existsSync(f)) return fs.readFileSync(f, 'utf8').trim();
  const s = crypto.randomBytes(32).toString('hex');
  fs.writeFileSync(f, s);
  return s;
}
const SECRET = loadSecret();

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');

/** 简化版 JWT（HS256） */
export function sign(payload, ttlSec = 7 * 24 * 3600) {
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64({ ...payload, exp: Math.floor(Date.now() / 1000) + ttlSec });
  const sig = crypto.createHmac('sha256', SECRET).update(`${head}.${body}`).digest('base64url');
  return `${head}.${body}.${sig}`;
}

export function verify(token) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) return null;
  const sig = crypto.createHmac('sha256', SECRET).update(`${parts[0]}.${parts[1]}`).digest('base64url');
  const a = Buffer.from(sig);
  const b = Buffer.from(parts[2]);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const p = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    if (p.exp < Date.now() / 1000) return null;
    return p;
  } catch {
    return null;
  }
}

export function hashPassword(pwd) {
  const salt = crypto.randomBytes(16).toString('hex');
  const h = crypto.scryptSync(pwd, salt, 64).toString('hex');
  return `${salt}:${h}`;
}

export function checkPassword(pwd, stored) {
  const [salt, h] = String(stored).split(':');
  if (!salt || !h) return false;
  const x = crypto.scryptSync(pwd, salt, 64);
  const y = Buffer.from(h, 'hex');
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

const bearer = (req) => (req.headers.authorization || '').replace(/^Bearer\s+/i, '');

/** C 端用户鉴权 */
export function requireUser(req, _res, next) {
  const p = verify(bearer(req));
  if (!p || p.typ !== 'user') return next(E.unauth());
  const u = one('SELECT * FROM users WHERE id = ?', p.uid);
  if (!u) return next(E.unauth('账号不存在'));
  if (u.status === 2) return next(E.forbidden('账号已冻结，请联系客服'));
  req.user = u;
  next();
}

/** 管理后台鉴权 */
export function requireAdmin(req, _res, next) {
  const p = verify(bearer(req));
  if (!p || p.typ !== 'admin') return next(E.unauth());
  const a = one('SELECT id, username, name FROM admins WHERE id = ?', p.aid);
  if (!a) return next(E.unauth('管理员不存在'));
  req.admin = a;
  next();
}
