import { describe, expect, it } from 'vitest';

import { corsHeaders } from '../src/infra/cors';
import type { Env } from '../src/types/env';

function request(origin?: string): Request {
  return new Request('https://busaogyn-api.example/v1/health', {
    headers: origin ? { Origin: origin } : undefined,
  });
}

describe('CORS policy', () => {
  const env: Env = {
    ALLOWED_ORIGINS: 'https://app.example.com,http://localhost:*,http://127.0.0.1:*',
  };

  it('allows exact configured production origin', () => {
    expect(corsHeaders(request('https://app.example.com'), env)).toMatchObject({
      'Access-Control-Allow-Origin': 'https://app.example.com',
    });
  });

  it('allows Flutter web on any localhost development port', () => {
    expect(corsHeaders(request('http://localhost:54321'), env)).toMatchObject({
      'Access-Control-Allow-Origin': 'http://localhost:54321',
    });
    expect(corsHeaders(request('http://127.0.0.1:60000'), env)).toMatchObject({
      'Access-Control-Allow-Origin': 'http://127.0.0.1:60000',
    });
  });

  it('rejects lookalike and non-http localhost origins', () => {
    expect(corsHeaders(request('http://localhost.evil.example:54321'), env)).toEqual({});
    expect(corsHeaders(request('https://localhost:54321'), env)).toEqual({});
  });

  it('returns no CORS headers when Origin is absent', () => {
    expect(corsHeaders(request(), env)).toEqual({});
  });
});
