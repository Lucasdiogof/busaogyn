const VEHICLES_URL = new URL('https://rmtcgoiania.com.br/index.php');
VEHICLES_URL.search = new URLSearchParams({
  option: 'com_rmtclinhas',
  view: 'cconaweb',
  format: 'json',
  linha: '000',
}).toString();

const ARRIVALS_URL = 'https://simapp.rmtcgoiania.com.br/pontoparada/previsaochegada';
const STOPS = ['00300', '1286'];

async function timed(label, fn) {
  const started = performance.now();
  try {
    const value = await fn();
    return { ok: true, label, durationMs: Math.round(performance.now() - started), value };
  } catch (error) {
    return {
      ok: false,
      label,
      durationMs: Math.round(performance.now() - started),
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

function asArray(payload) {
  if (Array.isArray(payload)) return payload;
  if (payload && Array.isArray(payload.onibus)) return payload.onibus;
  return null;
}

const vehiclesResult = await timed('vehicles:all', async () => {
  const response = await fetch(VEHICLES_URL, { headers: { Accept: 'application/json' } });
  const text = await response.text();
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  let payload;
  try { payload = JSON.parse(text); } catch { throw new Error(`invalid JSON: ${text.slice(0, 120)}`); }
  const vehicles = asArray(payload);
  if (!vehicles) throw new Error('unexpected payload shape');
  return vehicles;
});

const summary = {
  runAt: new Date().toISOString(),
  vehicles: {
    ok: vehiclesResult.ok,
    durationMs: vehiclesResult.durationMs,
    count: vehiclesResult.ok ? vehiclesResult.value.length : null,
    error: vehiclesResult.ok ? null : vehiclesResult.error,
  },
  statuses: {},
  route020Count: 0,
  invalidCoordinates: 0,
  arrivals: [],
  idMatches: { checked: 0, matched: 0, missing: 0, routeMatched: 0 },
};

const vehicleMap = new Map();
if (vehiclesResult.ok) {
  for (const bus of vehiclesResult.value) {
    const number = String(bus?.Numero ?? '').trim();
    const route = String(bus?.Linha?.LinhaNumero ?? '').trim().padStart(3, '0');
    const status = String(bus?.Situacao ?? 'null');
    summary.statuses[status] = (summary.statuses[status] ?? 0) + 1;
    if (route === '020') summary.route020Count += 1;
    const lat = Number(bus?.Latitude);
    const lng = Number(bus?.Longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      summary.invalidCoordinates += 1;
    }
    if (number) vehicleMap.set(number, { route, destination: bus?.Destino?.DestinoCurto ?? null });
  }
}

for (const stopId of STOPS) {
  const result = await timed(`arrivals:${stopId}`, async () => {
    const response = await fetch(ARRIVALS_URL, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
      },
      body: new URLSearchParams({ qryIdPontoParada: stopId }),
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    try { return JSON.parse(text); } catch { throw new Error(`invalid JSON: ${text.slice(0, 120)}`); }
  });

  const item = {
    stopId,
    ok: result.ok,
    durationMs: result.durationMs,
    groups: result.ok && Array.isArray(result.value?.data) ? result.value.data.length : null,
    error: result.ok ? null : result.error,
    realtimeWithVehicle: 0,
    idMatches: 0,
  };

  if (result.ok && Array.isArray(result.value?.data)) {
    for (const group of result.value.data) {
      const route = String(group?.Linha ?? '').trim().padStart(3, '0');
      for (const arrival of [group?.Proximo, group?.Seguinte]) {
        if (!arrival) continue;
        const quality = String(arrival?.Qualidade ?? '').trim().toLowerCase();
        const number = String(arrival?.NumeroOnibus ?? '').trim();
        if (quality === 'tempo real' && number) {
          item.realtimeWithVehicle += 1;
          summary.idMatches.checked += 1;
          const vehicle = vehicleMap.get(number);
          if (vehicle) {
            item.idMatches += 1;
            summary.idMatches.matched += 1;
            if (vehicle.route === route) summary.idMatches.routeMatched += 1;
          } else {
            summary.idMatches.missing += 1;
          }
        }
      }
    }
  }
  summary.arrivals.push(item);
}

console.log(JSON.stringify(summary, null, 2));

if (!vehiclesResult.ok) process.exitCode = 1;
