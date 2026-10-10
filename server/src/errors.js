/** 业务异常：code 沿用 App 端 AABCC 规约 */
export class ApiError extends Error {
  constructor(code, message, http = 400) {
    super(message);
    this.code = code;
    this.http = http;
  }
}

export const E = {
  bad: (m) => new ApiError(40001, m, 400),
  unauth: (m = '未登录或登录已过期') => new ApiError(40101, m, 401),
  forbidden: (m = '无权访问') => new ApiError(40301, m, 403),
  notFound: (m = '资源不存在') => new ApiError(40401, m, 404),
  conflict: (m) => new ApiError(40901, m, 409),
  balance: (m) => new ApiError(50301, m, 400),
  stock: (m) => new ApiError(50302, m, 400),
};

export const ok = (res, data = null, message = 'success') => res.json({ code: 0, message, data, server_time: Date.now() });

/** 包装 async 路由，统一错误输出 */
export const h = (fn) => (req, res, next) => {
  try {
    const out = fn(req, res, next);
    if (out && typeof out.then === 'function') {
      out.then((d) => { if (!res.headersSent) ok(res, d); }).catch(next);
    } else if (!res.headersSent) {
      ok(res, out);
    }
  } catch (e) {
    next(e);
  }
};

export function errorHandler(err, req, res, _next) {
  if (err instanceof ApiError) {
    return res.status(err.http).json({ code: err.code, message: err.message, data: null, server_time: Date.now() });
  }
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({ code: 40001, message: '请求体不是合法 JSON', data: null });
  }
  console.error('[ERROR]', req.method, req.originalUrl, err);
  res.status(500).json({ code: 50001, message: '服务器内部错误', data: null, server_time: Date.now() });
}

/** 参数取值工具 */
export const num = (v, name, { min, max, int = false, required = true } = {}) => {
  if (v === undefined || v === null || v === '') {
    if (required) throw E.bad(`${name} 不能为空`);
    return undefined;
  }
  const n = Number(v);
  if (Number.isNaN(n)) throw E.bad(`${name} 必须是数字`);
  if (int && !Number.isInteger(n)) throw E.bad(`${name} 必须是整数`);
  if (min !== undefined && n < min) throw E.bad(`${name} 不能小于 ${min}`);
  if (max !== undefined && n > max) throw E.bad(`${name} 不能大于 ${max}`);
  return n;
};

export const str = (v, name, { min = 1, max = 200, required = true } = {}) => {
  if (v === undefined || v === null || String(v).trim() === '') {
    if (required) throw E.bad(`${name} 不能为空`);
    return undefined;
  }
  const s = String(v).trim();
  if (s.length < min) throw E.bad(`${name} 至少 ${min} 个字符`);
  if (s.length > max) throw E.bad(`${name} 最多 ${max} 个字符`);
  return s;
};
