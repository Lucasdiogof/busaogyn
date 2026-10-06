import { readCache, writeCache } from '../cache/cache';
import type { TrackedVehicle } from '../domain/tracked-vehicle';
import { RmtcVehiclePositionSource } from '../sources/rmtc/vehicle-position.source';
import type { Env } from '../types/env';
import type { ServiceResult } from './result';

const POLICY = { freshSeconds: 5, staleSeconds: 45 } as const;

function ageSeconds(fetchedAt: string): number {
  return Math.max(0, Math.floor((Date.now() - Date.parse(fetchedAt)) / 1000));
}

export class VehiclePositionService {
  private readonly source: RmtcVehiclePositionSource;

  constructor(env: Env) {
    this.source = new RmtcVehiclePositionSource(env);
  }

  async getVehiclePosition(
    vehicleNumber: string,
    stopId: string,
  ): Promise<ServiceResult<TrackedVehicle | null>> {
    const key = `vehicle-position:${vehicleNumber}:stop:${stopId}`;
    const cached = await readCache<TrackedVehicle | null>(key);

    if (cached.state === 'fresh' && cached.value !== null) {
      return {
        data: cached.value.data,
        fetchedAt: cached.value.fetchedAt,
        cache: 'HIT',
        stale: false,
        ageSeconds: ageSeconds(cached.value.fetchedAt),
      };
    }

    try {
      const vehicle = await this.source.getVehiclePosition(vehicleNumber, stopId);
      const stored = await writeCache(key, vehicle, POLICY);
      return {
        data: vehicle,
        fetchedAt: stored.fetchedAt,
        cache: 'MISS',
        stale: false,
        ageSeconds: 0,
      };
    } catch (error) {
      if (cached.state === 'stale' && cached.value !== null) {
        return {
          data: cached.value.data,
          fetchedAt: cached.value.fetchedAt,
          cache: 'STALE',
          stale: true,
          ageSeconds: ageSeconds(cached.value.fetchedAt),
        };
      }
      throw error;
    }
  }
}
