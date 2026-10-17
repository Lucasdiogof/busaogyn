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

describe('experimental fleet routes', () => {
  it('lists all vehicles and by route', async () => {
    all.mockResolvedValue(result([{ id: 1 }, { id: 2 }]));
    byRoute.mockResolvedValue(result([{ id: 1 }]));
    expect(await (await call('/v1/vehicles')).json()).toMatchObject({ meta: { count: 2 } });
    expect(await (await call('/v1/routes/003/vehicles')).json()).toMatchObject({ meta: { routeId: '003', count: 1 } });
  });
});
