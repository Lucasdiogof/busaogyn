import type { Vehicle, VehicleStatus } from '../../domain/vehicle';
import { AppError } from '../../infra/errors';
import { fetchWithPolicy } from '../../infra/http-client';
import type { Env } from '../../types/env';
import {
  asNonEmptyString,
  normalizeRouteId,
  parseBoolean,
  parseCoordinate,
} from '../../utils/normalize';

const BASE_URL = 'https://rmtcgoiania.com.br/index.php';

interface RawRecord {
  [key: string]: unknown;
}

function asRecord(value: unknown): RawRecord | null {
  return typeof value === 'object' && value !== null ? (value as RawRecord) : null;
}

function mapStatus(value: unknown): { status: VehicleStatus; raw: string | null } {
  const raw = asNonEmptyString(value);
  if (raw === null) return { status: 'unknown', raw: null };
  const normalized = raw.toLowerCase().replace(/\s+/g, '');
  if (normalized === 'foraservico' || normalized === 'foraserviço') {
    return { status: 'out_of_service', raw };
  }
  if (normalized === 'intervalo') return { status: 'interval', raw };
  return { status: 'unknown', raw };
}

export function parseRmtcVehicle(value: unknown): Vehicle | null {
  const raw = asRecord(value);
  if (raw === null) return null;

  const vehicleNumber = asNonEmptyString(raw.Numero);
  if (vehicleNumber === null) return null;

  const line = asRecord(raw.Linha);
  const destination = asRecord(raw.Destino);
  const latitude = parseCoordinate(raw.Latitude, -90, 90);
  const longitude = parseCoordinate(raw.Longitude, -180, 180);
  const status = mapStatus(raw.Situacao);

  return {
    id: `rmtc:${vehicleNumber}`,
    vehicleNumber,
    routeId: normalizeRouteId(line?.LinhaNumero),
    destination: asNonEmptyString(destination?.DestinoCurto),
    position:
      latitude !== null && longitude !== null
        ? { latitude, longitude }
        : null,
    accessible: parseBoolean(raw.Acessivel),
    status: status.status,
    sourceStatus: status.raw,
  };
}

export function parseRmtcVehiclePayload(payload: unknown): Vehicle[] {
  let records: unknown[] | null = null;
  if (Array.isArray(payload)) {
    records = payload;
  } else {
    const raw = asRecord(payload);
    if (raw !== null && Array.isArray(raw.onibus)) records = raw.onibus;
  }

  if (records === null) {
    throw new AppError('SOURCE_INVALID_RESPONSE', 'RMTC vehicle payload has an unexpected shape.', 502, true);
  }

  return records.map(parseRmtcVehicle).filter((vehicle): vehicle is Vehicle => vehicle !== null);
}

export class RmtcCconawebSource {
  constructor(private readonly env: Env) {}

  async getAllVehicles(): Promise<Vehicle[]> {
    const url = new URL(BASE_URL);
    url.search = new URLSearchParams({
      option: 'com_rmtclinhas',
      view: 'cconaweb',
      format: 'json',
      linha: '000',
    }).toString();

    const response = await fetchWithPolicy(
      url,
      {
        method: 'GET',
        headers: {
          Accept: 'application/json',
        },
      },
      { timeoutMs: Number(this.env.RMTC_VEHICLES_TIMEOUT_MS ?? 5000), retries: 1 },
    );

    if (!response.ok) {
      throw new AppError('SOURCE_UNAVAILABLE', `RMTC vehicle source returned HTTP ${response.status}.`, 503, true);
    }

    const text = await response.text();

    if (/tipo de acesso inv[aá]lido/i.test(text)) {
      throw new AppError(
        'SOURCE_ACCESS_RESTRICTED',
        'RMTC vehicle source rejected this server access context.',
        503,
        false,
      );
    }

    let payload: unknown;
    try {
      payload = JSON.parse(text);
    } catch (error) {
      throw new AppError(
        'SOURCE_INVALID_RESPONSE',
        'RMTC vehicle source returned a non-JSON response.',
        502,
        true,
        { cause: error },
      );
    }

    return parseRmtcVehiclePayload(payload);
  }
}
