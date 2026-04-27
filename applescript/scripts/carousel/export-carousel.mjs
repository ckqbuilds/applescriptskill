import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const URL = process.argv[2] ?? 'http://127.0.0.1:8765/.superpowers/brainstorm/carousel-v9/content/carousel-v12.html';
const OUT_DIR = resolve(process.argv[3] ?? './carousel-export');
const SCALE = Number(process.argv[4] ?? 2);
const ONLY = process.argv[5]
  ? new Set(process.argv[5].split(',').map((n) => Number(n.trim())))
  : null;

await mkdir(OUT_DIR, { recursive: true });

const browser = await chromium.launch({ channel: 'chrome' });
const context = await browser.newContext({ deviceScaleFactor: SCALE });
const page = await context.newPage();

await page.setViewportSize({ width: 1280, height: 1500 });
await page.goto(URL, { waitUntil: 'networkidle' });

const count = await page.locator('.matte').count();
console.log(`Found ${count} slides at ${URL}`);

let exported = 0;
for (let i = 0; i < count; i++) {
  if (ONLY && !ONLY.has(i + 1)) continue;
  const slide = page.locator('.matte').nth(i);
  const file = `${OUT_DIR}/slide-${String(i + 1).padStart(2, '0')}.png`;
  await slide.screenshot({ path: file, omitBackground: false });
  console.log(`  → ${file}`);
  exported++;
}

await browser.close();
console.log(`Done. ${exported} slide(s) exported to ${OUT_DIR} at ${SCALE}× density.`);
