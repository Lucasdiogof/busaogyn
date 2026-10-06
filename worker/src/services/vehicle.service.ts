import { readCache, writeCache } from '../cache/cache';
import type { Vehicle } from '../domain/vehicle';
import { RmtcCconawebSource } from '../sources/rmtc/cconaweb.source';
import type { Env } from '../types/env';
import { normalizeRouteId } from '../utils/normalize';
import type { ServiceResult } from './result';

const POLICY = { freshSeconds: 10, staleSeconds: 90 } as const;
const KEY = 'vehicles:all';

function ageSeconds(fetchedAt: string): number {
  return Math.max(0, Math.floor((Date.now() - Date.parse(fetchedAt)) / 1000));
}

function visibleVehicle(vehicle: Vehicle): boolean {
  return vehicle.status !== 'out_of_service' && vehicle.status !== 'interval';
}

export class VehicleService {
  private readonly source: RmtcCconawebSource;

  constructor(env: Env) {
    this.source = new RmtcCconawebSource(env);
  }

  async getAllVehicles(): Promise<ServiceResult<Vehicle[]>> {
    const cached = await readCache<Vehicle[]>(KEY);
    if (cached.state === 'fresh' && cached.value !== null) {
      return {
        data: cached.value.data.filter(visibleVehicle),
        fetchedAt: cached.value.fetchedAt,
        cache: 'HIT',
        stale: false,
        ageSeconds: ageSeconds(cached.value.fetchedAt),
      };
    }

    try {
      const vehicles = await this.source.getAllVehicles();
      const stored = await writeCache(KEY, vehicles, POLICY);
      return { data: vehicles.filter(visibleVehicle), fetchedAt: stored.fetchedAt, cache: 'MISS', stale: false, ageSeconds: 0 };
    } catch (error) {
      if (cached.state === 'stale' && cached.value !== null) {
        return {
          data: cached.value.data.filter(visibleVehicle),
          fetchedAt: cached.value.fetchedAt,
          cache: 'STALE',
          stale: true,
          ageSeconds: ageSeconds(cached.value.fetchedAt),
        };
      }
      throw error;
    }
  }

  async getVehiclesByRoute(routeId: string): Promise<ServiceResult<Vehicle[]>> {
    const canonical = normalizeRouteId(routeId);
    const result = await this.getAllVehicles();
    return { ...result, data: result.data.filter((vehicle) => vehicle.routeId === canonical) };
  }
}
