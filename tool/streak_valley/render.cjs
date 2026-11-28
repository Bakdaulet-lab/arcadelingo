// Offline authoring tool. Requires Node, Playwright/Chromium and Python/Pillow.
// node tool/streak_valley/render.cjs
// CHROME_PATH can point at an already installed Chromium executable.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { chromium } = require('playwright');

const output = path.join(__dirname, '../../assets/streak_valley');
const dataUrl = file => 'data:image/jpeg;base64,' + fs.readFileSync(path.join(__dirname,file)).toString('base64');
const encoder = [
  'import sys, io',
  'from PIL import Image',
  'image=Image.open(io.BytesIO(sys.stdin.buffer.read()))',
  'background=sys.argv[1]=="land"',
  'image=image.convert("RGB" if background else "RGBA")',
  'image.save(sys.argv[2], format="WEBP", lossless=not background, quality=90, method=4)'
].join('\n');
function writeAsset(kind, day, theme, data) {
  const file = path.join(output, theme, kind+'_'+day+'.webp');
  const input = Buffer.from(data.split(',')[1], 'base64');
  const process = spawnSync('python', ['-c',encoder,kind,file], {input, windowsHide:true});
  if (process.status !== 0) throw Error(String(process.stderr));
}
async function main() {
  const browser = await chromium.launch({executablePath:process.env.CHROME_PATH, headless:true});
  try {
    const page = await browser.newPage();
    for (const name of ['pixel-dawn.js','pixel-grove.js','pixel-summit.js','pixel.js','frames.js']) {
      await page.addScriptTag({path:path.join(__dirname,name)});
    }
    await page.evaluate(async ([base, finale]) => {
      async function image(src) {
        const picture = new Image();
        picture.src = src;
        await picture.decode();
        return picture;
      }
      window.landscapes = await Promise.all([image(base), image(finale)]);
    }, [dataUrl('pixel.jpg'), dataUrl('pixel_final.jpg')]);
    const days = await page.evaluate(() => valleyDays);
    const landscapeDays = [1,7,35,42,60,90,100];
    for (const theme of ['dark','light']) {
      fs.mkdirSync(path.join(output,theme), {recursive:true});
      for (const day of landscapeDays) {
        const data = await page.evaluate(([d,l]) => landscape(...window.landscapes,d,l).toDataURL(), [day,theme==='light']);
        writeAsset('land',day,theme,data);
      }
    }
    for (const day of days) {
      for (const theme of ['dark','light']) {
        for (const kind of ['badge','scene']) {
          const data = await page.evaluate(([k,d,l]) => sheet(k,d,l).toDataURL(), [kind,day,theme==='light']);
          writeAsset(kind,day,theme,data);
        }
      }
      console.log('Rendered day', day);
    }
  } finally {
    await browser.close();
  }
}
main().catch(error => {console.error(error); process.exitCode=1;});
