import type { Env } from '../types/env';

function matchesAllowedOrigin(origin: string, allowedOrigin: string): boolean {
  if (origin === allowedOrigin) return true;

  if (
    allowedOrigin !== 'http://localhost:*' &&
    allowedOrigin !== 'http://127.0.0.1:*'
  ) {
    return false;
  }

  try {
    const url = new URL(origin);
    if (url.protocol !== 'http:') return false;

    if (allowedOrigin === 'http://localhost:*') {
      return url.hostname === 'localhost';
    }

    return url.hostname === '127.0.0.1';
  } catch {
    return false;
  }
}

export function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get('Origin');
  if (origin === null) return {};

  const allowedOrigins = (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

  if (!allowedOrigins.some((allowedOrigin) => matchesAllowedOrigin(origin, allowedOrigin))) {
    return {};
  }

  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Request-ID',
    Vary: 'Origin',
  };
}
