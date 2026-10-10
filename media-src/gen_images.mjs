// 批量生成图片（seedream_5.0_lite），可重入：job state 记录 nodeId/submitId
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { SUBS } from 'file:///E:/老猫智能版体集群/huazhai/paymo/server/src/catalog.js';
import { PAGE_IMAGES, LABOR_IMAGES } from './images.mjs';

const P = '24ae5423-ef73-4ca8-a9b1-5775ac9e067a';
const HERO = 'node_a71222dr2k';
const STATE = 'C:/Users/ROG/AppData/Local/Temp/gencode/image_state.json';
const A = '0123456789abcdefghjkmnpqrstvwxyz';
const nid = () => 'node_' + Array.from(crypto.randomBytes(10), (b) => A[b % 32]).join('');
const st = fs.existsSync(STATE) ? JSON.parse(fs.readFileSync(STATE, 'utf8')) : {};
const save = () => fs.writeFileSync(STATE, JSON.stringify(st, null, 2));
const dc = (args) => {
  try { return JSON.parse(execFileSync('dreamina-canvas', ['--non-interactive', ...args], { encoding: 'utf8', maxBuffer: 1 << 24 })); } catch (e) {
    try { return JSON.parse(e.stdout?.toString()); } catch { return { ok: false, raw: e.message }; }
  }
};

const jobs = [
  ...Object.entries(SUBS).map(([k, v]) => [`goods_${k}`, '1:1', `${v.img}，正方形构图，无任何文字、无品牌标志、无水印`, false]),
  ...PAGE_IMAGES,
  ...LABOR_IMAGES,
];
console.log('total jobs', jobs.length);
for (const [key, ratio, prompt, withHero] of jobs) {
  const it = (st[key] ||= { nodeId: nid(), submitId: crypto.randomUUID() });
  if (it.submitted) continue;
  const args = ['node', 'create', 'image', '--project-id', P, '--node-id', it.nodeId, '--submit-id', it.submitId, '--title', key, '--model', 'seedream_5.0_lite', '--ratio', ratio, '--resolution', '2K', '--run', '--credit-ceiling', '1'];
  if (withHero) args.push('--mode', 'i2i', '--ref', `node:${HERO}`, '--prompt', `参考图 {{node:${HERO}}} 中的人物。${prompt}`);
  else args.push('--mode', 't2i', '--prompt', prompt);
  const r = dc(args);
  if (r.ok) it.submitted = true;
  else console.log('FAIL', key, JSON.stringify(r.error || r.raw).slice(0, 300));
  save();
}
console.log('submitted', Object.values(st).filter((x) => x.submitted).length);
