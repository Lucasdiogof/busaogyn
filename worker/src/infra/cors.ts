import type { Env } from '../types/env';

export function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get('Origin');
  if (origin === null) return {};
  const allowed = new Set((env.ALLOWED_ORIGINS ?? '').split(',').map((item) => item.trim()).filter(Boolean));
  if (!allowed.has(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Request-ID',
    Vary: 'Origin',
  };
}
