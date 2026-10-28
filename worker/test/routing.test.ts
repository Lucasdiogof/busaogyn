import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { Env } from '../src/types/env';

const arrivals = vi.fn();
const position = vi.fn();
const all = vi.fn();
const byRoute = vi.fn();

vi.mock('../src/services/arrival.service', () => ({
  ArrivalService: class {
    getArrivals = arrivals;
  },
}));
vi.mock('../src/services/vehicle-position.service', () => ({
  VehiclePositionService: class {
    getVehiclePosition = position;
  },
}));
vi.mock('../src/services/vehicle.service', () => ({
  VehicleService: class {
    getAllVehicles = all;
    getVehiclesByRoute = byRoute;
  },
}));

const { default: worker } = await import('../src/index');

const env: Env = { ENVIRONMENT: 'test', API_VERSION: '1', BUILD_SHA: 'abc', ALLOWED_ORIGINS: 'https://app.example.com' };
const result = (data: unknown) => ({ data, fetchedAt: '2026-10-17T12:00:00.000Z', cache: 'MISS', stale: false, ageSeconds: 0 });

function call(path: string, init?: RequestInit): Promise<Response> {
  return worker.fetch(new Request(`https://api.example${path}`, init), env);
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.spyOn(console, 'log').mockImplementation(() => undefined);
});

describe('routing', () => {
  it('answers health and version', async () => {
    expect(await (await call('/v1/health')).json()).toEqual({ status: 'ok', environment: 'test', apiVersion: '1' });
    expect(await (await call('/v1/version/')).json()).toEqual({ api: '1', build: 'abc' });
  });

  it('returns 404 for unknown paths', async () => {
    const response = await call('/v1/nope');
    expect(response.status).toBe(404);
    expect(((await response.json()) as { error: { code: string } }).error.code).toBe('NOT_FOUND');
  });

  it('accepts only GET and OPTIONS', async () => {
    expect((await call('/v1/health', { method: 'POST' })).status).toBe(405);
    expect((await call('/v1/health', { method: 'OPTIONS' })).status).toBe(204);
  });

  it('adds a request id and echoes an incoming one', async () => {
    expect((await call('/v1/health')).headers.get('X-Request-ID')).toBeTruthy();
    const response = await call('/v1/health', { headers: { 'X-Request-ID': 'req-1' } });
    expect(response.headers.get('X-Request-ID')).toBe('req-1');
  });

  it('applies CORS only to allowed origins', async () => {
    const allowed = await call('/v1/health', { headers: { Origin: 'https://app.example.com' } });
    expect(allowed.headers.get('Access-Control-Allow-Origin')).toBe('https://app.example.com');
    const denied = await call('/v1/health', { headers: { Origin: 'https://evil.example' } });
    expect(denied.headers.get('Access-Control-Allow-Origin')).toBeNull();
  });
});

describe('arrivals route', () => {
  it('returns data with meta and keeps leading zeros of the stop', async () => {
    arrivals.mockResolvedValue(result([{ routeId: '003' }]));
    const response = await call('/v1/stops/00402/arrivals');
    expect(response.status).toBe(200);
    expect(arrivals).toHaveBeenCalledWith('00402');
    expect(await response.json()).toMatchObject({
      data: [{ routeId: '003' }],
      meta: { stopId: '00402', count: 1, stale: false, ageSeconds: 0 },
    });
  });

  it('rejects a non numeric stop without calling the service', async () => {
    const response = await call('/v1/stops/abc/arrivals');
    expect(response.status).toBe(400);
    expect(((await response.json()) as { error: { code: string } }).error.code).toBe('INVALID_STOP');
    expect(arrivals).not.toHaveBeenCalled();
  });

  it('turns an unexpected service failure into a generic 500', async () => {
    arrivals.mockRejectedValue(new Error('secret upstream detail'));
    const response = await call('/v1/stops/30402/arrivals');
    expect(response.status).toBe(500);
    const body = (await response.json()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('INTERNAL_ERROR');
    expect(JSON.stringify(body)).not.toContain('secret');
  });
});

describe('vehicle position route', () => {
  it('accepts the rmtc: prefix and reports stale data', async () => {
    position.mockResolvedValue({ ...result({ vehicleNumber: '20529' }), stale: true, ageSeconds: 30 });
    const response = await call('/v1/vehicles/rmtc:20529/position?stopId=30402');
    expect(response.status).toBe(200);
    expect(position).toHaveBeenCalledWith('20529', '30402');
    expect(await response.json()).toMatchObject({
      meta: { vehicleId: 'rmtc:20529', stopId: '30402', stale: true, ageSeconds: 30 },
    });
  });

  it('requires a numeric vehicle and a stopId', async () => {
    const badVehicle = await call('/v1/vehicles/abc/position?stopId=30402');
    expect(badVehicle.status).toBe(400);
    expect(((await badVehicle.json()) as { error: { code: string } }).error.code).toBe('INVALID_VEHICLE');
    const noStop = await call('/v1/vehicles/20529/position');
    expect(noStop.status).toBe(400);
    expect(((await noStop.json()) as { error: { code: string } }).error.code).toBe('INVALID_STOP');
    expect(position).not.toHaveBeenCalled();
  });
});

describe('batch vehicle positions route', () => {
  it('returns each vehicle with its own meta, in request order, deduplicated', async () => {
    position.mockImplementation(async (n: string) => ({ ...result({ vehicleNumber: n }), ageSeconds: n === '2' ? 7 : 0 }));
    const response = await call('/v1/stops/30402/vehicle-positions?vehicles=1,2,1,3');
    expect(response.status).toBe(200);
    expect(position.mock.calls).toEqual([['1', '30402'], ['2', '30402'], ['3', '30402']]);
    const body = (await response.json()) as { data: { vehicleNumber: string; meta: { ageSeconds: number } }[]; meta: unknown };
    expect(body.data.map((d) => d.vehicleNumber)).toEqual(['1', '2', '3']);
    expect(body.data[1]?.meta.ageSeconds).toBe(7);
    expect(body.meta).toEqual({ stopId: '30402', count: 3 });
  });

  it('isolates a failing vehicle without leaking details', async () => {
    position.mockImplementation(async (n: string) => {
      if (n === '2') throw new Error('secret upstream detail');
      return result({ vehicleNumber: n });
    });
    const response = await call('/v1/stops/30402/vehicle-positions?vehicles=1,2');
    expect(response.status).toBe(200);
    const text = await response.text();
    expect(text).not.toContain('secret');
    const body = JSON.parse(text) as { data: { vehicleNumber: string; data: unknown; error?: { code: string } }[] };
    expect(body.data[0]?.data).toEqual({ vehicleNumber: '1' });
    expect(body.data[1]).toMatchObject({ vehicleNumber: '2', data: null, error: { code: 'INTERNAL_ERROR' } });
  });

  it('validates the stop and the vehicle list before calling the service', async () => {
    for (const query of ['', 'vehicles=', 'vehicles=1,abc', `vehicles=${Array.from({ length: 9 }, (_, i) => i + 1).join(',')}`]) {
      const response = await call(`/v1/stops/30402/vehicle-positions?${query}`);
      expect(response.status).toBe(400);
      expect(((await response.json()) as { error: { code: string } }).error.code).toBe('INVALID_VEHICLE');
    }
    expect((await call('/v1/stops/abc/vehicle-positions?vehicles=1')).status).toBe(400);
    expect(position).not.toHaveBeenCalled();
  });

  it('never queries more than three vehicles at once', async () => {
    let running = 0;
    let peak = 0;
    position.mockImplementation(async (n: string) => {
      running++;
      peak = Math.max(peak, running);
      await new Promise((resolve) => setTimeout(resolve, 5));
      running--;
      return result({ vehicleNumber: n });
    });
    await call('/v1/stops/30402/vehicle-positions?vehicles=1,2,3,4,5,6,7');
    expect(position).toHaveBeenCalledTimes(7);
    expect(peak).toBe(3);
  });
});

describe('experimental fleet routes', () => {
  it('lists all vehicles and by route', async () => {
    all.mockResolvedValue(result([{ id: 1 }, { id: 2 }]));
    byRoute.mockResolvedValue(result([{ id: 1 }]));
    expect(await (await call('/v1/vehicles')).json()).toMatchObject({ meta: { count: 2 } });
    expect(await (await call('/v1/routes/003/vehicles')).json()).toMatchObject({ meta: { routeId: '003', count: 1 } });
  });
});
