// 拉取已完成的图片/视频/音频资源到 media/raw
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const P = '24ae5423-ef73-4ca8-a9b1-5775ac9e067a';
const RAW = 'C:/Users/ROG/AppData/Local/Temp/gencode/media/raw';
fs.mkdirSync(RAW, { recursive: true });
const dc = (args) => {
  try { return JSON.parse(execFileSync('dreamina-canvas', ['--non-interactive', ...args], { encoding: 'utf8', maxBuffer: 1 << 24 })); } catch (e) {
    try { return JSON.parse(e.stdout?.toString()); } catch { return { ok: false }; }
  }
};
const status = (submitId) => {
  const r = dc(['operation', 'status', submitId, '--project-id', P]);
  return { state: r.data?.state, rid: r.data?.resources?.[0]?.resourceId, rstate: r.data?.resources?.[0]?.state, err: r.error?.code };
};
const get = (name, submitId, ext) => {
  const f = `${RAW}/${name}.${ext}`;
  if (fs.existsSync(f)) return 'have';
  const s = status(submitId);
  if (s.state !== 'succeeded' || !s.rid) return s.state || s.err;
  const r = dc(['resource', 'download', s.rid, '--project-id', P, '-o', f]);
  return r.ok ? 'downloaded' : `dl-fail ${JSON.stringify(r.error).slice(0, 120)}`;
};

const tally = {};
const img = JSON.parse(fs.readFileSync('C:/Users/ROG/AppData/Local/Temp/gencode/image_state.json', 'utf8'));
for (const [k, v] of Object.entries(img)) { const r = get(k, v.submitId, 'png'); tally[r] = (tally[r] || 0) + 1; if (!['have', 'downloaded', 'running', 'pending', 'queued'].includes(r)) console.log('img', k, r); }
const vs = JSON.parse(fs.readFileSync('C:/Users/ROG/AppData/Local/Temp/gencode/video_state.json', 'utf8')).items;
for (const [k, v] of Object.entries(vs)) {
  const a = get(`${k}_voice`, v.audioSubmit, 'mp3');
  const b = get(`${k}`, v.videoSubmit, 'mp4');
  console.log(k, 'voice:', a, 'video:', b);
}
console.log('images', tally);
