import type { Arrival, ArrivalGroup, ArrivalQuality } from '../../domain/arrival';
import { AppError } from '../../infra/errors';
import { fetchWithPolicy } from '../../infra/http-client';
import type { Env } from '../../types/env';
import {
  asNonEmptyString,
  normalizeRouteId,
  parseNonNegativeInteger,
} from '../../utils/normalize';

const ENDPOINT = 'https://simapp.rmtcgoiania.com.br/pontoparada/previsaochegada';

interface RawRecord {
  [key: string]: unknown;
}

function asRecord(value: unknown): RawRecord | null {
  return typeof value === 'object' && value !== null ? (value as RawRecord) : null;
}

function mapQuality(value: unknown): { quality: ArrivalQuality; raw: string | null } {
  const raw = asNonEmptyString(value);
  if (raw === null) return { quality: 'unknown', raw: null };
  const normalized = raw.toLowerCase();
  if (normalized === 'tempo real') return { quality: 'realtime', raw };
  if (normalized.includes('aprox') || normalized.includes('program')) {
    return { quality: 'scheduled', raw };
  }
  return { quality: 'unknown', raw };
}

function parseArrival(value: unknown): Arrival | null {
  const raw = asRecord(value);
  if (raw === null) return null;

  const vehicleNumber = asNonEmptyString(raw.NumeroOnibus);
  const quality = mapQuality(raw.Qualidade);

  return {
    vehicleId: vehicleNumber === null ? null : `rmtc:${vehicleNumber}`,
    vehicleNumber,
    minutes: parseNonNegativeInteger(raw.PrevisaoChegada),
    plannedArrival: asNonEmptyString(raw.HoraChegadaPlanejada),
    predictedArrival: asNonEmptyString(raw.HoraChegadaPrevista),
    realtime: quality.quality === 'realtime',
    quality: quality.quality,
    sourceQuality: quality.raw,
  };
}

export function parseRmtcArrivalPayload(payload: unknown): ArrivalGroup[] {
  const root = asRecord(payload);
  if (root === null || !Array.isArray(root.data)) {
    throw new AppError('SOURCE_INVALID_RESPONSE', 'RMTC arrivals payload has an unexpected shape.', 502, true);
  }

  const groups: ArrivalGroup[] = [];
  for (const value of root.data) {
    const raw = asRecord(value);
    if (raw === null) continue;
    const routeId = normalizeRouteId(raw.Linha);
    const next = parseArrival(raw.Proximo);
    if (routeId === null || next === null) continue;

    groups.push({
      routeId,
      destination: asNonEmptyString(raw.Destino),
      next,
      following: parseArrival(raw.Seguinte),
    });
  }
  return groups;
}

export class RmtcArrivalSource {
  constructor(private readonly env: Env) {}

  async getArrivals(stopId: string): Promise<ArrivalGroup[]> {
    const body = new URLSearchParams({ qryIdPontoParada: stopId });
    const response = await fetchWithPolicy(
      ENDPOINT,
      {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        },
        body,
      },
      { timeoutMs: Number(this.env.RMTC_ARRIVALS_TIMEOUT_MS ?? 6000), retries: 1 },
    );

    if (!response.ok) {
      throw new AppError('SOURCE_UNAVAILABLE', `RMTC arrivals source returned HTTP ${response.status}.`, 503, true);
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch (error) {
      throw new AppError('SOURCE_INVALID_RESPONSE', 'RMTC arrivals source returned invalid JSON.', 502, true, { cause: error });
    }

    return parseRmtcArrivalPayload(payload);
  }
}
