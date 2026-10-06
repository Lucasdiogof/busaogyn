import type { ServiceResult } from '../services/result';

export function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...headers,
    },
  });
}

export function serviceHeaders<T>(result: ServiceResult<T>): Record<string, string> {
  return {
    'X-BusaoGyn-Cache': result.cache,
    'X-BusaoGyn-Stale': String(result.stale),
  };
}
