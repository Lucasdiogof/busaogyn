const BASE = process.env.BUSAOGYN_API_BASE_URL ?? 'http://127.0.0.1:8787';
const EXPECTED_ENVIRONMENT = process.env.BUSAOGYN_EXPECTED_ENVIRONMENT ?? null;
const STOP = '30402';
const TARGET_ROUTE = '020';

async function get(path) {
  const response = await fetch(BASE + path);
  const text = await response.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`${path}: invalid JSON: ${text.slice(0, 160)}`);
  }
  if (!response.ok) {
    throw new Error(`${path}: HTTP ${response.status}: ${text.slice(0, 240)}`);
  }
  return { json, headers: response.headers };
}

function realtimeCandidates(groups) {
  const unique = new Map();

  for (const group of groups) {
    if (group?.routeId !== TARGET_ROUTE) continue;

    for (const item of [group.next, group.following]) {
      if (!item?.realtime || !item?.vehicleNumber) continue;
      const vehicleNumber = String(item.vehicleNumber);
      unique.set(vehicleNumber, {
        routeId: String(group.routeId),
        vehicleNumber,
      });
    }
  }

  return [...unique.values()];
}

async function findTrackableVehicle(candidates) {
  const failures = [];

  for (const candidate of candidates) {
    const path =
      `/v1/vehicles/${encodeURIComponent(candidate.vehicleNumber)}/position?stopId=${STOP}`;

    try {
      const position = await get(path);
      const vehicle = position.json.data;

      if (!vehicle) {
        failures.push(`${candidate.vehicleNumber}: position returned null`);
        continue;
      }

      if (String(vehicle.vehicleNumber) !== candidate.vehicleNumber) {
        failures.push(
          `${candidate.vehicleNumber}: vehicle mismatch position=${vehicle.vehicleNumber}`,
        );
        continue;
      }

      if (vehicle.routeId !== candidate.routeId) {
        failures.push(
          `${candidate.vehicleNumber}: route mismatch position=${vehicle.routeId}`,
        );
        continue;
      }

      if (
        !vehicle.position ||
        typeof vehicle.position.latitude !== 'number' ||
        typeof vehicle.position.longitude !== 'number'
      ) {
        failures.push(`${candidate.vehicleNumber}: normalized position missing`);
        continue;
      }

      return { selected: candidate, vehicle, failures };
    } catch (error) {
      failures.push(
        `${candidate.vehicleNumber}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  throw new Error(
    `no trackable realtime vehicle found for route ${TARGET_ROUTE}; attempts: ${failures.join(' | ')}`,
  );
}

const health = await get('/v1/health');
if (health.json.status !== 'ok') throw new Error('health is not ok');
if (EXPECTED_ENVIRONMENT && health.json.environment !== EXPECTED_ENVIRONMENT) {
  throw new Error(
    `unexpected environment: expected=${EXPECTED_ENVIRONMENT} actual=${health.json.environment}`,
  );
}

const arrivals = await get(`/v1/stops/${STOP}/arrivals`);
if (!Array.isArray(arrivals.json.data) || arrivals.json.data.length === 0) {
  throw new Error('no arrival groups returned');
}

const candidates = realtimeCandidates(arrivals.json.data);
if (candidates.length === 0) {
  throw new Error(
    `no realtime arrival with vehicle number found for route ${TARGET_ROUTE}`,
  );
}

const { selected, vehicle, failures } = await findTrackableVehicle(candidates);
const secondArrivals = await get(`/v1/stops/${STOP}/arrivals`);

console.log(
  JSON.stringify(
    {
      health: health.json,
      stopId: STOP,
      arrivalGroups: arrivals.json.data.length,
      realtimeCandidates: candidates.map((candidate) => candidate.vehicleNumber),
      failedCandidates: failures,
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
    },
    null,
    2,
  ),
);
