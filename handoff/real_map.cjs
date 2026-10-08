const { chromium } = require('playwright');
const out = process.argv[2];
const [W, H] = (process.argv[3] || '390x844').split('x').map(Number);
const scheme = process.argv[4] || 'dark';
const tag = process.argv[5] || 'shot';
const mode = process.argv[6] || 'track';   // 'track' | 'idle'
const base = { lat: -16.6869, lon: -49.2648 };
let step = 0;
const now = () => new Date().toISOString();
function vehicle(number, lat, lon, route, dest) {
  return { id: `rmtc:${number}`, vehicleNumber: number, routeId: route, routeName: null, destination: dest,
    position: { latitude: lat, longitude: lon }, accessible: true, punctuality: { status: 'on_time', sourceStatus: null },
    referenceStop: null, prediction: null };
}
(async () => {
  const proxy = process.env.HTTPS_PROXY;
  const browser = await chromium.launch({
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl',
      ...(proxy ? [`--proxy-server=${proxy}`, '--proxy-bypass-list=127.0.0.1;localhost'] : [])] });
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, colorScheme: scheme, locale: 'pt-BR' });
  const page = await ctx.newPage();
  const logs = [];
  page.on('console', m => { if (m.type() === 'error') logs.push(m.text()); });
  await page.route('https://busaogyn-api.lively-cloud-f009.workers.dev/**', async route => {
    const url = new URL(route.request().url());
    const headers = { 'content-type': 'application/json', 'access-control-allow-origin': '*' };
    let body;
    if (url.pathname.endsWith('/arrivals')) {
      const a = (n, m) => ({ vehicleId: `rmtc:${n}`, vehicleNumber: n, minutes: m, plannedArrival: null, predictedArrival: null, realtime: true, quality: 'realtime', sourceQuality: null });
      body = { data: [
        { routeId: '003', destination: 'T PAULO GARCIA', next: a('20693', 3), following: a('20051', 14) },
        { routeId: '020', destination: 'T. BIBLIA', next: a('20529', 7), following: null },
      ], meta: { fetchedAt: now(), stale: false, ageSeconds: 0 } };
    } else {
      const n = url.pathname.split('/')[3];
      if (n === '20693') {
        step++;
        // Move ~60 m to northeast each sample: real observed heading.
        body = { data: vehicle(n, base.lat + 0.0004 * step, base.lon + 0.0004 * step, '003', 'T PAULO GARCIA'), meta: { fetchedAt: now(), stale: false, ageSeconds: 0 } };
      } else if (n === '20051') {
        body = { data: vehicle(n, base.lat - 0.004, base.lon + 0.003, '003', 'T PAULO GARCIA'), meta: { fetchedAt: now(), stale: false, ageSeconds: 3 } };
      } else {
        body = { data: vehicle(n, base.lat + 0.003, base.lon - 0.004, '020', 'T. BIBLIA'), meta: { fetchedAt: now(), stale: false, ageSeconds: 3 } };
      }
    }
    await route.fulfill({ status: 200, headers, body: JSON.stringify(body) });
  });
  await page.goto('http://127.0.0.1:8766/', { waitUntil: 'load' });
  await page.waitForTimeout(9000);
  // Liga a semântica do Flutter para clicar por rótulo acessível.
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1000);
  if (mode !== 'idle') {
    const field = page.locator('input').first();
    await field.click(); await field.fill('30402'); await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);
    await page.getByRole('button', { name: 'Acompanhar ônibus 20693' }).first().click();
    // 3 amostras reais (consulta a cada 15 s): direção + rastro observados.
    await page.waitForTimeout(34000);
  }
  await page.screenshot({ path: `${out}/${tag}.png` });
  console.log(tag, 'errors:', logs.slice(0, 5));
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
