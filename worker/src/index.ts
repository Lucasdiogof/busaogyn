import { AppError } from './infra/errors';
import { corsHeaders } from './infra/cors';
import { logEvent } from './infra/logger';
import { json, serviceHeaders } from './infra/response';
import { ArrivalService } from './services/arrival.service';
import { VehicleService } from './services/vehicle.service';
import type { Env } from './types/env';
import { normalizeStopId } from './utils/normalize';

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
