import { AppError } from './infra/errors';
import { corsHeaders } from './infra/cors';
import { logEvent } from './infra/logger';
import { json, serviceHeaders } from './infra/response';
import { ArrivalService } from './services/arrival.service';
import { VehicleService } from './services/vehicle.service';
import { VehiclePositionService } from './services/vehicle-position.service';
import type { Env } from './types/env';
import { normalizeStopId } from './utils/normalize';

/** Até 8 ônibus por pedido (o app mostra no máximo 6 secundários). */
const MAX_BATCH_VEHICLES = 8;
/** Consultas simultâneas à RMTC num pedido em lote (igual ao app). */
const BATCH_CONCURRENCY = 3;

function withCommonHeaders(response: Response, requestId: string, cors: Record<string, string>): Response {
  const headers = new Headers(response.headers);
  headers.set('X-Request-ID', requestId);
  for (const [key, value] of Object.entries(cors)) headers.set(key, value);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

async function handleRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/$/, '') || '/';

  if (request.method === 'OPTIONS') return new Response(null, { status: 204 });
  if (request.method !== 'GET') return json({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Method not allowed.', retryable: false } }, 405);

  if (path === '/v1/health') {
    return json({ status: 'ok', environment: env.ENVIRONMENT ?? 'unknown', apiVersion: env.API_VERSION ?? '1' });
  }

  if (path === '/v1/version') {
    return json({ api: env.API_VERSION ?? '1', build: env.BUILD_SHA ?? 'development' });
  }

  const vehicleService = new VehicleService(env);
  if (path === '/v1/vehicles') {
    const result = await vehicleService.getAllVehicles();
    return json(
      { data: result.data, meta: { count: result.data.length, fetchedAt: result.fetchedAt, stale: result.stale, ageSeconds: result.ageSeconds } },
      200,
      serviceHeaders(result),
    );
  }

  const routeMatch = path.match(/^\/v1\/routes\/([^/]+)\/vehicles$/);
  if (routeMatch !== null) {
    const routeId = routeMatch[1] ?? '';
    const result = await vehicleService.getVehiclesByRoute(routeId);
    return json(
      { data: result.data, meta: { routeId, count: result.data.length, fetchedAt: result.fetchedAt, stale: result.stale, ageSeconds: result.ageSeconds } },
      200,
      serviceHeaders(result),
    );
  }

  const positionMatch = path.match(/^\/v1\/vehicles\/([^/]+)\/position$/);
  if (positionMatch !== null) {
    const rawVehicle = decodeURIComponent(positionMatch[1] ?? '').trim();
    const vehicleNumber = rawVehicle.startsWith('rmtc:') ? rawVehicle.slice(5) : rawVehicle;
    const stopId = normalizeStopId(url.searchParams.get('stopId') ?? '');
    if (!/^\d+$/.test(vehicleNumber)) {
      throw new AppError('INVALID_VEHICLE', 'Vehicle id must be an RMTC numeric vehicle number.', 400, false);
    }
    if (stopId === null) {
      throw new AppError('INVALID_STOP', 'A numeric stopId query parameter is required.', 400, false);
    }

    const result = await new VehiclePositionService(env).getVehiclePosition(vehicleNumber, stopId);
    return json(
      {
        data: result.data,
        meta: {
          vehicleId: `rmtc:${vehicleNumber}`,
          stopId,
          fetchedAt: result.fetchedAt,
          stale: result.stale,
          ageSeconds: result.ageSeconds,
        },
      },
      200,
      serviceHeaders(result),
    );
  }

  // Posições de vários ônibus de um ponto num só pedido: mesmo serviço e
  // mesmo cache por ônibus da rota individual; só economiza requisições.
  const batchMatch = path.match(/^\/v1\/stops\/([^/]+)\/vehicle-positions$/);
  if (batchMatch !== null) {
    const stopId = normalizeStopId(batchMatch[1] ?? '');
    if (stopId === null) throw new AppError('INVALID_STOP', 'Stop id must contain only digits.', 400, false);
    const numbers = [
      ...new Set(
        (url.searchParams.get('vehicles') ?? '')
          .split(',')
          .map((item) => item.trim())
          .filter(Boolean),
      ),
    ];
    if (numbers.length === 0 || numbers.length > MAX_BATCH_VEHICLES || numbers.some((n) => !/^\d+$/.test(n))) {
      throw new AppError(
        'INVALID_VEHICLE',
        `vehicles must list 1 to ${MAX_BATCH_VEHICLES} numeric RMTC vehicle numbers.`,
        400,
        false,
      );
    }
    const service = new VehiclePositionService(env);
    const results: unknown[] = [];
    for (let i = 0; i < numbers.length; i += BATCH_CONCURRENCY) {
      const chunk = numbers.slice(i, i + BATCH_CONCURRENCY);
      results.push(
        ...(await Promise.all(
          chunk.map(async (vehicleNumber) => {
            try {
              const result = await service.getVehiclePosition(vehicleNumber, stopId);
              return {
                vehicleNumber,
                data: result.data,
                meta: { fetchedAt: result.fetchedAt, stale: result.stale, ageSeconds: result.ageSeconds },
              };
            } catch (error) {
              // Um ônibus que falha não derruba os outros; sem detalhe interno.
              const appError = error instanceof AppError ? error : null;
              return {
                vehicleNumber,
                data: null,
                error: { code: appError?.code ?? 'INTERNAL_ERROR', retryable: appError?.retryable ?? false },
              };
            }
          }),
        )),
      );
    }
    return json({ data: results, meta: { stopId, count: results.length } });
  }

  const arrivalMatch = path.match(/^\/v1\/stops\/([^/]+)\/arrivals$/);
  if (arrivalMatch !== null) {
    const stopId = normalizeStopId(arrivalMatch[1] ?? '');
    if (stopId === null) throw new AppError('INVALID_STOP', 'Stop id must contain only digits.', 400, false);
    const result = await new ArrivalService(env).getArrivals(stopId);
    return json(
      { data: result.data, meta: { stopId, count: result.data.length, fetchedAt: result.fetchedAt, stale: result.stale, ageSeconds: result.ageSeconds } },
      200,
      serviceHeaders(result),
    );
  }

  return json({ error: { code: 'NOT_FOUND', message: 'Endpoint not found.', retryable: false } }, 404);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const requestId = request.headers.get('X-Request-ID') ?? crypto.randomUUID();
    const cors = corsHeaders(request, env);
    const startedAt = Date.now();

    try {
      const response = await handleRequest(request, env);
      logEvent({ requestId, method: request.method, path: new URL(request.url).pathname, status: response.status, durationMs: Date.now() - startedAt });
      return withCommonHeaders(response, requestId, cors);
    } catch (error) {
      const appError = error instanceof AppError
        ? error
        : new AppError('INTERNAL_ERROR', 'Unexpected internal error.', 500, false, { cause: error });
      logEvent({ requestId, method: request.method, path: new URL(request.url).pathname, status: appError.status, errorCode: appError.code, durationMs: Date.now() - startedAt });
      return withCommonHeaders(
        json({ error: { code: appError.code, message: appError.message, retryable: appError.retryable } }, appError.status),
        requestId,
        cors,
      );
    }
  },
} satisfies ExportedHandler<Env>;
