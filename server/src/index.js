import { DB_FILE, migrate } from './db.js';
import { seed } from './seed.js';
import { seedLabor } from './seed_labor.js';
import { runLaborJobs } from './services/labor.js';
import { createApp } from './app.js';
import { runOrderJobs } from './services/orders.js';
import { settleDueCommissions } from './services/finance.js';

migrate();
const { createdAdmin } = seed();
seedLabor();

const PORT = Number(process.env.PORT || 8080);
const HOST = process.env.HOST || '0.0.0.0';

createApp().listen(PORT, HOST, () => {
  console.log(`[xinguang] 数据库: ${DB_FILE}`);
  console.log(`[xinguang] 服务已启动: http://localhost:${PORT}`);
  console.log(`[xinguang]   用户端 App : http://localhost:${PORT}/`);
  console.log(`[xinguang]   管理后台   : http://localhost:${PORT}/admin/`);
  console.log(`[xinguang]   API        : http://localhost:${PORT}/api/health`);
  if (createdAdmin) console.log(`[xinguang] 已创建管理员 ${createdAdmin.username} / ${createdAdmin.password}（请登录后立即修改密码）`);
});

// 定时任务：每分钟执行超时关单、自动确认收货、到期佣金入账
const tick = () => {
  try {
    const o = runOrderJobs();
    const s = settleDueCommissions();
    const l = runLaborJobs();
    if (l.timeout || l.autoPass || l.closed) console.log(`[jobs] 微劳动 超时 ${l.timeout} · 自动验收 ${l.autoPass} · 到期退押金 ${l.closed}`);
    if (o.cancelled || o.confirmed || s) console.log(`[jobs] 关单 ${o.cancelled} · 自动收货 ${o.confirmed} · 佣金入账 ${s}`);
  } catch (e) {
    console.error('[jobs]', e);
  }
};
setInterval(tick, 60_000).unref?.();
tick();
