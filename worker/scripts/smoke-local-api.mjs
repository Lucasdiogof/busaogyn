const BASE = process.env.BUSAOGYN_API_BASE_URL ?? 'http://127.0.0.1:8787';
const EXPECTED_ENVIRONMENT = process.env.BUSAOGYN_EXPECTED_ENVIRONMENT ?? null;
const STOP = '30402';
const TARGET_ROUTE = '020';

async function get(path) {
  const response = await fetch(BASE + path);
  const text = await response.text();
  let json;
  try { json = JSON.parse(text); } catch { throw new Error(`${path}: invalid JSON: ${text.slice(0, 160)}`); }
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}: ${text.slice(0, 240)}`);
  return { json, headers: response.headers };
}

const health = await get('/v1/health');
if (health.json.status !== 'ok') throw new Error('health is not ok');
if (EXPECTED_ENVIRONMENT && health.json.environment !== EXPECTED_ENVIRONMENT) {
  throw new Error(`unexpected environment: expected=${EXPECTED_ENVIRONMENT} actual=${health.json.environment}`);
}

const arrivals = await get(`/v1/stops/${STOP}/arrivals`);
if (!Array.isArray(arrivals.json.data) || arrivals.json.data.length === 0) {
  throw new Error('no arrival groups returned');
}

let selected = null;
for (const group of arrivals.json.data) {
  for (const item of [group.next, group.following]) {
    if (
      group.routeId === TARGET_ROUTE &&
      item?.realtime &&
      item?.vehicleNumber
    ) {
      selected = { routeId: group.routeId, vehicleNumber: String(item.vehicleNumber) };
      break;
    }
  }
  if (selected) break;
}
if (!selected) throw new Error(`no realtime arrival with vehicle number found for route ${TARGET_ROUTE}`);

const position = await get(
  `/v1/vehicles/${encodeURIComponent(selected.vehicleNumber)}/position?stopId=${STOP}`,
);
const vehicle = position.json.data;
if (!vehicle) throw new Error('vehicle position returned null');
if (String(vehicle.vehicleNumber) !== selected.vehicleNumber) {
  throw new Error(`vehicle mismatch: ETA=${selected.vehicleNumber} position=${vehicle.vehicleNumber}`);
}
if (vehicle.routeId !== selected.routeId) {
  throw new Error(`route mismatch: ETA=${selected.routeId} position=${vehicle.routeId}`);
}
if (!vehicle.position || typeof vehicle.position.latitude !== 'number' || typeof vehicle.position.longitude !== 'number') {
  throw new Error('normalized vehicle position missing');
}

const secondArrivals = await get(`/v1/stops/${STOP}/arrivals`);

console.log(JSON.stringify({
  health: health.json,
  stopId: STOP,
  arrivalGroups: arrivals.json.data.length,
  selected,
  position: {
    id: vehicle.id,
    routeId: vehicle.routeId,
    destination: vehicle.destination,
    position: vehicle.position,
    accessible: vehicle.accessible,
    punctuality: vehicle.punctuality,
  },
  firstCache: arrivals.headers.get('x-busaogyn-cache'),
  secondCache: secondArrivals.headers.get('x-busaogyn-cache'),
  stale: secondArrivals.headers.get('x-busaogyn-stale'),
}, null, 2));
