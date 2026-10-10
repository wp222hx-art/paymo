// 提交 10 条视频 + 10 条解说，记录 job state，可重入（复用 nodeId/submitId，不会重复扣费）
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import crypto from 'node:crypto';
const A='0123456789abcdefghjkmnpqrstvwxyz';const nid=()=>'node_'+Array.from(crypto.randomBytes(10),b=>A[b%32]).join('');

const P = '24ae5423-ef73-4ca8-a9b1-5775ac9e067a';
const HERO = 'node_a71222dr2k';
const STATE = 'C:/Users/ROG/AppData/Local/Temp/gencode/video_state.json';
const vids = JSON.parse(fs.readFileSync('C:/Users/ROG/AppData/Local/Temp/gencode/videos.json', 'utf8'));
const st = fs.existsSync(STATE) ? JSON.parse(fs.readFileSync(STATE, 'utf8')) : { items: {} };
const save = () => fs.writeFileSync(STATE, JSON.stringify(st, null, 2));
const dc = (args) => {
  try {
    return JSON.parse(execFileSync('dreamina-canvas', ['--non-interactive', ...args], { encoding: 'utf8', maxBuffer: 1 << 24 }));
  } catch (e) {
    const out = e.stdout?.toString() || '';
    try { return JSON.parse(out); } catch { return { ok: false, raw: out || e.message }; }
  }
};

const only = process.argv[2]; // 'audio' | 'video' | undefined(both)
for (const v of vids) {
  const it = (st.items[v.key] ||= { videoNode: nid(), videoSubmit: crypto.randomUUID(), audioNode: nid(), audioSubmit: crypto.randomUUID() });
  save();
  if (only !== 'video' && !it.audioDone) {
    const r = dc(['node', 'create', 'audio', '--project-id', P, '--node-id', it.audioNode, '--submit-id', it.audioSubmit, '--title', `解说·${v.title}`, '--mode', 'tts', '--voice-name', '温柔女声', '--prompt', v.narration, '--run', '--credit-ceiling', '3']);
    if (!r.ok && /already|exist|conflict/i.test(JSON.stringify(r.error || r.raw))) {
      const r2 = dc(['node', 'run', '--project-id', P, '--node-id', it.audioNode, '--submit-id', it.audioSubmit]);
      console.log('audio rerun', v.key, r2.ok, JSON.stringify(r2.error || '').slice(0, 200));
    } else console.log('audio', v.key, r.ok, JSON.stringify(r.error || '').slice(0, 300));
    if (r.ok) it.audioDone = true;
    save();
  }
  if (only !== 'audio' && !it.videoDone) {
    const ceiling = v.model === 'seedance_2.0_vip' ? '210' : '60';
    const prompt = v.prompt.replaceAll('HERO', HERO);
    const r = dc(['node', 'create', 'video', '--project-id', P, '--node-id', it.videoNode, '--submit-id', it.videoSubmit, '--title', v.title, '--mode', 'm2v', '--model', v.model, '--ratio', '9:16', '--resolution', '720p', '--duration', String(v.duration), '--ref', `node:${HERO}`, '--prompt', prompt, '--run', '--credit-ceiling', ceiling]);
    console.log('video', v.key, r.ok, JSON.stringify(r.error || '').slice(0, 300));
    if (r.ok) it.videoDone = true;
    save();
  }
}
console.log(JSON.stringify(st, null, 1).slice(0, 3000));
