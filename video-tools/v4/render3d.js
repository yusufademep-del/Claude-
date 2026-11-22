// usage: node render3d.js <out.mp4|test> <dur> <fps> [times...]
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs'); const path = require('path');
(async () => {
  const [out, dur, fps, ...times] = process.argv.slice(2);
  const seg = encodeURIComponent(fs.readFileSync(path.join(__dirname, 'seg.json'), 'utf8'));
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  p.on('pageerror', e => console.error('PAGEERR', e)); p.on('console', m => { if (m.type() === 'error') console.error('CONSOLE', m.text()); });
  await p.goto('file://' + path.join(__dirname, 'scene3d.html') + '?w=1080&h=1920&seg=' + seg);
  await p.waitForFunction(() => window.READY === true, null, { timeout: 60000 });
  const grab = async (t) => {
    const d = await p.evaluate((t) => { renderAt(t); return document.querySelector('canvas').toDataURL('image/jpeg', 0.93); }, t);
    return Buffer.from(d.split(',')[1], 'base64');
  };
  if (out === 'test') {
    for (const t of times) { const t0 = Date.now(); const buf = await grab(+t); fs.writeFileSync(path.join(__dirname, `test_${t}.jpg`), buf); console.log('t', t, 'ms', Date.now() - t0); }
  } else {
    const N = Math.round(+dur * +fps);
    const ff = spawn('ffmpeg', ['-v', 'error', '-y', '-f', 'image2pipe', '-framerate', fps, '-c:v', 'mjpeg', '-i', '-', '-c:v', 'libx264', '-preset', 'fast', '-crf', '14', '-pix_fmt', 'yuv420p', out], { stdio: ['pipe', 'inherit', 'inherit'] });
    const T0 = Date.now();
    for (let i = 0; i < N; i++) {
      const buf = await grab(i / +fps);
      if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
      if (i % 120 === 0) console.log('frame', i, '/', N, ((Date.now() - T0) / 1000).toFixed(0) + 's');
    }
    ff.stdin.end(); await new Promise(r => ff.on('close', r));
    console.log('done', N, ((Date.now() - T0) / 1000).toFixed(0) + 's');
  }
  await b.close();
})();
