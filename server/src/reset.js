import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// 不导入 db.js，避免打开数据库导致 Windows 上无法删除文件
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dataDir = process.env.DATA_DIR || path.join(root, 'data');
const file = process.env.DB_FILE || path.join(dataDir, 'xinguang.db');

for (const f of [file, `${file}-wal`, `${file}-shm`]) {
  try { fs.rmSync(f); } catch { /* ignore */ }
}
console.log(`已删除 ${file}，下次启动将重新初始化种子数据（请先停止服务）`);
