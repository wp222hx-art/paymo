import express from 'express';
import cors from 'cors';
import compression from 'compression';
import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from './db.js';
import { E, errorHandler, h } from './errors.js';
import { markPaid } from './services/orders.js';
import { one } from './db.js';
import appRoutes, { DEMO_MODE } from './routes/app.js';
import adminRoutes from './routes/admin.js';
import laborRoutes from './routes/labor.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(compression());
  app.use(cors({ origin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : true }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/api/health', (_req, res) => res.json({ code: 0, data: { ok: true, demo_mode: DEMO_MODE, time: new Date().toISOString() } }));

  // 模拟第三方收银台（微信/支付宝）：生产环境替换为真实支付网关的异步通知 + 验签
  app.get('/api/pay/mock/:payNo', h((req) => {
    const p = one('SELECT pay_no, channel, amount, status FROM payments WHERE pay_no = ?', req.params.payNo);
    if (!p) throw E.notFound('支付单不存在');
    return p;
  }));
  app.post('/api/pay/mock/:payNo/confirm', h((req) => {
    if (!DEMO_MODE) throw E.forbidden('模拟支付已关闭');
    return markPaid(req.params.payNo, `MOCK${Date.now()}`);
  }));

  app.use('/api/app', laborRoutes);
  app.use('/api/app', appRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api', (_req, _res, next) => next(E.notFound('接口不存在')));

  // 静态资源：上传图片 / 管理后台 / Flutter Web App
  const pub = path.join(ROOT, 'public');
  app.use('/uploads', express.static(path.join(pub, 'uploads'), { maxAge: '7d' }));
  // 生成的图片/视频：文件名固定，强缓存 30 天；视频支持 Range 分段加载
  app.use('/media', express.static(path.join(pub, 'media'), { maxAge: '30d', immutable: true, acceptRanges: true }));
  const spa = (prefix, dir) => {
    if (!fs.existsSync(dir)) return;
    app.use(prefix, express.static(dir, { index: 'index.html' }));
    app.get(`${prefix === '/' ? '' : prefix}/*`, (req, res, next) => (req.accepts('html') ? res.sendFile(path.join(dir, 'index.html')) : next()));
  };
  spa('/admin', path.join(pub, 'admin'));
  spa('/', path.join(pub, 'app'));

  app.use(errorHandler);
  return app;
}
