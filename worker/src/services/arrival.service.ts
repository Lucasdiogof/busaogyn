import { readCache, writeCache } from '../cache/cache';
import type { ArrivalGroup } from '../domain/arrival';
import { RmtcArrivalSource } from '../sources/rmtc/arrivals.source';
import type { Env } from '../types/env';
import type { ServiceResult } from './result';

const POLICY = { freshSeconds: 15, staleSeconds: 60 } as const;

function ageSeconds(fetchedAt: string): number {
  return Math.max(0, Math.floor((Date.now() - Date.parse(fetchedAt)) / 1000));
}

export class ArrivalService {
  private readonly source: RmtcArrivalSource;

  constructor(env: Env) {
    this.source = new RmtcArrivalSource(env);
  }

  async getArrivals(stopId: string): Promise<ServiceResult<ArrivalGroup[]>> {
    const key = `arrivals:stop:${stopId}`;
    const cached = await readCache<ArrivalGroup[]>(key);
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
      const arrivals = await this.source.getArrivals(stopId);
      const stored = await writeCache(key, arrivals, POLICY);
      return { data: arrivals, fetchedAt: stored.fetchedAt, cache: 'MISS', stale: false, ageSeconds: 0 };
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
