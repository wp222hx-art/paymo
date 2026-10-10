import { ElMessage } from 'element-plus';

const KEY = 'xg_admin_token';
export const getToken = () => localStorage.getItem(KEY);
export const setToken = (t) => (t ? localStorage.setItem(KEY, t) : localStorage.removeItem(KEY));

/** 统一请求：解析 {code,message,data}，非 0 抛错并提示 */
export async function api(method, url, body, { silent = false } = {}) {
  const isForm = body instanceof FormData;
  const res = await fetch(`/api/admin${url}`, {
    method,
    headers: { ...(isForm ? {} : { 'content-type': 'application/json' }), ...(getToken() ? { authorization: `Bearer ${getToken()}` } : {}) },
    body: body ? (isForm ? body : JSON.stringify(body)) : undefined,
  });
  let j;
  try {
    j = await res.json();
  } catch {
    j = { code: res.status, message: `请求失败 (${res.status})` };
  }
  if (j.code === 40101) {
    setToken(null);
    if (!location.hash.includes('/login')) location.hash = '#/login';
  }
  if (j.code !== 0) {
    if (!silent) ElMessage.error(j.message || '请求失败');
    throw Object.assign(new Error(j.message), { code: j.code });
  }
  return j.data;
}

export const get = (u, o) => api('GET', u, null, o);
export const post = (u, b, o) => api('POST', u, b || {}, o);
export const put = (u, b, o) => api('PUT', u, b || {}, o);
export const patch = (u, b, o) => api('PATCH', u, b || {}, o);
export const del = (u, o) => api('DELETE', u, null, o);

export const money = (v) => `¥${Number(v || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
export const dp = (v) => `¥${Number(v || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`; // 清偿金
export const dt = (v) => (v ? new Date(v).toLocaleString('zh-CN', { hour12: false }) : '-');

export const ORDER_STATUS = { 10: ['待支付', 'info'], 20: ['待发货', 'warning'], 30: ['已发货', 'primary'], 40: ['已完成', 'success'], 50: ['已取消', 'info'], 60: ['退款中', 'danger'], 70: ['已退款', 'info'] };
export const COMMISSION_STATUS = { 0: ['待收货', 'info'], 1: ['保障期中', 'warning'], 2: ['已到账', 'success'], 9: ['已失效', 'info'] };
export const CLEAR_STATUS = { 10: ['已提交', 'warning'], 20: ['银行已受理', 'primary'], 30: ['资金已划转', 'primary'], 50: ['已核减', 'success'], 90: ['已退回', 'danger'] };
export const RULE_STATUS = { 0: ['草稿', 'info'], 1: ['灰度', 'warning'], 2: ['生产', 'success'], 3: ['关闭', 'info'] };
export const RULE_TYPE = { category: '品类基础倍率', credit_tier: '信用分加成', global_cap: '全局上限' };
export const LETTER_KIND = { accepted: ['接入确认', 'primary'], partial: ['清偿回执', 'success'], settled: ['偿清确认', 'warning'] };
