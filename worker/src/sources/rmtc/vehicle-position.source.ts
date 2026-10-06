import type { TrackedVehicle, VehiclePunctuality } from '../../domain/tracked-vehicle';
import { AppError } from '../../infra/errors';
import { fetchWithPolicy } from '../../infra/http-client';
import type { Env } from '../../types/env';
import {
  asNonEmptyString,
  normalizeRouteId,
  parseBoolean,
  parseCoordinate,
  parseNonNegativeInteger,
} from '../../utils/normalize';

const ENDPOINT = 'https://simapp.rmtcgoiania.com.br/veiculo/recuperarposicao';

interface RawRecord {
  [key: string]: unknown;
}

function asRecord(value: unknown): RawRecord | null {
  return typeof value === 'object' && value !== null ? (value as RawRecord) : null;
}

function mapPunctuality(value: unknown): { status: VehiclePunctuality; raw: string | null } {
  const raw = asNonEmptyString(value);
  if (raw === null) return { status: 'unknown', raw: null };
  const normalized = raw.toLowerCase().replace(/[\s_-]+/g, '');
  if (normalized === 'nohorario') return { status: 'on_time', raw };
  if (normalized === 'atrasado') return { status: 'delayed', raw };
  if (normalized === 'adiantado') return { status: 'early', raw };
  return { status: 'unknown', raw };
}

export function parseTrackedVehiclePayload(payload: unknown): TrackedVehicle | null {
  const root = asRecord(payload);
  if (root === null || !Array.isArray(root.data)) {
    throw new AppError(
      'SOURCE_INVALID_RESPONSE',
      'RMTC individual vehicle payload has an unexpected shape.',
      502,
      true,
    );
  }

  const first = asRecord(root.data[0]);
  if (first === null) return null;

  const vehicleNumber = asNonEmptyString(first.Numero);
  if (vehicleNumber === null) return null;

  const line = asRecord(first.Linha);
  const destination = asRecord(first.Destino);
  const position = asRecord(first.Posicao);
  const stop = asRecord(first.PontoParada);
  const prediction = asRecord(first.Previsao);
  const latitude = parseCoordinate(position?.Latitude, -90, 90);
  const longitude = parseCoordinate(position?.Longitude, -180, 180);
  const punctuality = mapPunctuality(first.Situacao);

  return {
    id: `rmtc:${vehicleNumber}`,
    vehicleNumber,
    routeId: normalizeRouteId(line?.LinhaNumero),
    routeName: asNonEmptyString(line?.LinhaItinerario),
    destination: asNonEmptyString(destination?.DestinoNome),
    position:
      latitude !== null && longitude !== null
        ? { latitude, longitude }
        : null,
    accessible: parseBoolean(first.Acessivel),
    punctuality: {
      status: punctuality.status,
      sourceStatus: punctuality.raw,
    },
    referenceStop:
      stop === null
        ? null
        : {
            sourceStopId: asNonEmptyString(stop.PontoId),
            address: asNonEmptyString(stop.PontoEndereco),
          },
    prediction:
      prediction === null
        ? null
        : {
            predictedArrival: asNonEmptyString(prediction.HoraChegadaPrevista),
            minutes: parseNonNegativeInteger(prediction.PrevisaoChegada),
          },
  };
}

export class RmtcVehiclePositionSource {
  constructor(private readonly env: Env) {}

  async getVehiclePosition(vehicleNumber: string, stopId: string): Promise<TrackedVehicle | null> {
    const response = await fetchWithPolicy(
      ENDPOINT,
      {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        },
        body: new URLSearchParams({
          qryIdVeiculo: vehicleNumber,
          qryIdPontoParada: stopId,
        }),
      },
      { timeoutMs: Number(this.env.RMTC_VEHICLES_TIMEOUT_MS ?? 5000), retries: 1 },
    );

    if (!response.ok) {
      throw new AppError(
        'SOURCE_UNAVAILABLE',
        `RMTC individual vehicle source returned HTTP ${response.status}.`,
        503,
        true,
      );
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch (error) {
      throw new AppError(
        'SOURCE_INVALID_RESPONSE',
        'RMTC individual vehicle source returned invalid JSON.',
        502,
        true,
        { cause: error },
      );
    }

    return parseTrackedVehiclePayload(payload);
  }
}
