// Twemoji-SVG -> PNG (256px) nach video-tools/icons. Nutzung: node emoji.js 1f4b0 1f4c8 ...
const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
const VT = path.dirname(__dirname), dir = path.join(VT, 'pkgs/twemoji-svg-15.0.0/package'), out = path.join(VT, 'icons');
(async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 256, height: 256 } });
  for (const c of process.argv.slice(2)) { const svg = fs.readFileSync(`${dir}/${c}.svg`, 'utf8');
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('<svg', '<svg width="256" height="256"')}</body></html>`);
    await p.screenshot({ path: `${out}/${c}.png`, omitBackground: true, clip: { x: 0, y: 0, width: 256, height: 256 } }); }
  await b.close(); })();
