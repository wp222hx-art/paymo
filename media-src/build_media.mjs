// 媒体后处理：图片 → WebP（多档尺寸）；视频 → 解说 + 字幕 + 压缩 + 封面
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import sharp from 'sharp';
import ffmpeg from 'ffmpeg-static';

const RAW = 'C:/Users/ROG/AppData/Local/Temp/gencode/media/raw';
const OUT = 'E:/老猫智能版体集群/huazhai/paymo/server/public/media';
const IMG = `${OUT}/img`;
const VID = `${OUT}/video`;
fs.mkdirSync(IMG, { recursive: true });
fs.mkdirSync(VID, { recursive: true });
const only = process.argv[2];

// ───── 图片 ─────
if (!only || only === 'img') {
  let total = 0;
  for (const f of fs.readdirSync(RAW).filter((x) => x.endsWith('.png'))) {
    const key = f.replace('.png', '');
    const meta = await sharp(`${RAW}/${f}`).metadata();
    const wide = meta.width / meta.height > 1.3;
    const main = key.startsWith('goods_') || key.startsWith('cat_') || ['orders_empty', 'cart_empty', 'empty_debt', 'clear_success'].includes(key) ? 640 : wide ? 1440 : 960;
    await sharp(`${RAW}/${f}`).resize({ width: main, withoutEnlargement: true }).webp({ quality: 74, effort: 5 }).toFile(`${IMG}/${key}.webp`);
    await sharp(`${RAW}/${f}`).resize({ width: 320, withoutEnlargement: true }).webp({ quality: 66, effort: 5 }).toFile(`${IMG}/${key}@s.webp`);
    total += fs.statSync(`${IMG}/${key}.webp`).size + fs.statSync(`${IMG}/${key}@s.webp`).size;
  }
  console.log('images total KB', Math.round(total / 1024));
}

// ───── 视频 ─────
if (!only || only === 'video') {
  const { GUIDES } = await import('file:///E:/老猫智能版体集群/huazhai/paymo/server/src/guides.js');
  const keyMap = { intro: 'v00_intro', bank: 'v01_bank', mall: 'v02_mall', pay: 'v03_pay', receive: 'v04_receive', credit: 'v05_credit', clear: 'v06_clear', progress: 'v07_progress', cert: 'v08_cert', score: 'v09_score', task: 'v10_task', submit: 'v11_submit', income: 'v12_income' };
  const probe = (f) => {
    try { execFileSync(ffmpeg, ['-hide_banner', '-i', f], { encoding: 'utf8' }); } catch (e) {
      const m = /Duration: (\d+):(\d+):([\d.]+)/.exec(e.stderr || e.stdout || '');
      return m ? +m[1] * 3600 + +m[2] * 60 + +m[3] : 0;
    }
    return 0;
  };
  const ts = (s) => {
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = (s % 60).toFixed(2).padStart(5, '0');
    return `${h}:${String(m).padStart(2, '0')}:${x}`;
  };
  for (const g of GUIDES) {
    const k = keyMap[g.key];
    const v = `${RAW}/${k}.mp4`;
    const a = `${RAW}/${k}_voice.mp3`;
    const vd = probe(v);
    const ad = probe(a);
    // 字幕：按标点切句，按字数比例分配时长；解说从 0.4s 开始
    const start = 0.4;
    const parts = g.narration.split(/(?<=[，。！？；])/).map((x) => x.trim()).filter(Boolean);
    // 合并过短片段，每条 8~20 字
    const lines = [];
    for (const p of parts) {
      const prev = lines.at(-1);
      if (prev && !/[。！？]$/.test(prev) && (prev.length + p.length <= 18 || p.length < 5)) lines[lines.length - 1] += p;
      else lines.push(p);
    }
    const chars = lines.reduce((s, l) => s + l.length, 0);
    let t = start;
    const ev = lines.map((l) => {
      const d = (l.length / chars) * ad;
      const e = `Dialogue: 0,${ts(t)},${ts(t + d)},Sub,,0,0,0,,${l.replace(/[，。；]$/, '')}`;
      t += d;
      return e;
    });
    const ass = `[Script Info]
ScriptType: v4.00+
PlayResX: 720
PlayResY: 1280
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Sub,Microsoft YaHei,40,&H00FFFFFF,&H00FFFFFF,&H64000000,&H8C000000,1,0,0,0,100,100,1,0,3,14,0,2,60,60,150,1
Style: Title,Microsoft YaHei,44,&H0042B9F5,&H00FFFFFF,&H00000000,&H64000000,1,0,0,0,100,100,2,0,1,3,2,8,60,60,110,1
Style: Tag,Microsoft YaHei,26,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,0,0,0,0,100,100,2,0,1,2,1,8,60,60,170,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 1,0:00:00.00,0:00:03.20,Title,,0,0,0,,{\\fad(300,400)}${g.step === 0 ? '星光云' : g.title}
Dialogue: 1,0:00:00.00,0:00:03.20,Tag,,0,0,0,,{\\fad(300,400)}${g.step === 0 ? '会花钱，也会轻松清偿' : g.group === 'labor' ? `微劳动 · ${g.subtitle}` : `第 ${g.step} 步 · ${g.subtitle}`}
${ev.join('\n')}
`;
    const assFile = `${RAW}/${g.key}.ass`;
    fs.writeFileSync(assFile, ass);
    // 视频长度取 max(画面, 解说+0.8s)，画面不足时定格最后一帧
    const dur = Math.max(vd, start + ad + 0.8);
    const pad = Math.max(0, dur - vd);
    const assEsc = assFile.replace(/\\/g, '/').replace(':', '\\:');
    const vf = `${pad > 0 ? `tpad=stop_mode=clone:stop_duration=${pad.toFixed(2)},` : ''}scale=720:1280,ass='${assEsc}':fontsdir='C\\:/Users/ROG/AppData/Local/Temp/gencode/fonts',fade=t=in:st=0:d=0.4,fade=t=out:st=${(dur - 0.5).toFixed(2)}:d=0.5`;
    const af = `[0:a]volume=0.18,apad[bg];[1:a]adelay=${Math.round(start * 1000)}|${Math.round(start * 1000)},volume=1.6,apad[vo];[bg][vo]amix=inputs=2:duration=longest:dropout_transition=0,atrim=0:${dur.toFixed(2)},afade=t=out:st=${(dur - 0.5).toFixed(2)}:d=0.5[a]`;
    const out = `${VID}/${g.key}.mp4`;
    const tmp = `${RAW}/${g.key}_final.mp4`;
    const only2 = process.argv[3];
    if (only2 && only2 !== g.key) continue;
    const enc = () => execFileSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error', '-i', v, '-i', a, '-filter_complex', af, '-vf', vf, '-map', '0:v', '-map', '[a]', '-t', dur.toFixed(2), '-c:v', 'libx264', '-preset', 'slow', '-crf', '27', '-maxrate', '1400k', '-bufsize', '2800k', '-pix_fmt', 'yuv420p', '-profile:v', 'main', '-r', '24', '-c:a', 'aac', '-b:a', '80k', '-ac', '1', '-movflags', '+faststart', tmp]);
    // libass 在 Windows 上偶发段错误（字体扫描），重试即可
    for (let i = 0; ; i++) { try { enc(); break; } catch (e) { if (i >= 6) throw e; console.log('retry', g.key, i + 1); } }
    for (let i = 0; ; i++) { try { fs.copyFileSync(tmp, out); break; } catch (e) { if (i > 10) throw e; await new Promise((r) => setTimeout(r, 1000)); } }
    // 封面：取第 2.5 秒画面（标题已叠加）
    const jpg = `${RAW}/${g.key}_poster.jpg`;
    execFileSync(ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error', '-ss', '2.0', '-i', tmp, '-frames:v', '1', '-q:v', '3', jpg]);
    await sharp(jpg).resize(540).webp({ quality: 70 }).toFile(`${VID}/${g.key}.webp`);
    console.log(g.key, `video ${vd.toFixed(1)}s voice ${ad.toFixed(1)}s → ${dur.toFixed(1)}s`, Math.round(fs.statSync(out).size / 1024), 'KB');
  }
}
