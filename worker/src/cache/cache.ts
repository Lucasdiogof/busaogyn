export interface CachePolicy {
  freshSeconds: number;
  staleSeconds: number;
}

export interface CachedValue<T> {
  data: T;
  fetchedAt: string;
  freshUntil: number;
  staleUntil: number;
}

export interface CacheRead<T> {
  value: CachedValue<T> | null;
  state: 'miss' | 'fresh' | 'stale';
}

function cacheRequest(key: string): Request {
  return new Request(`https://cache.busaogyn.internal/${encodeURIComponent(key)}`);
}

export async function readCache<T>(key: string): Promise<CacheRead<T>> {
  const cache = (caches as unknown as { default: Cache }).default;
  const response = await cache.match(cacheRequest(key));
  if (response === undefined) return { value: null, state: 'miss' };

  try {
    const value = (await response.json()) as CachedValue<T>;
    const now = Date.now();
    if (now <= value.freshUntil) return { value, state: 'fresh' };
    if (now <= value.staleUntil) return { value, state: 'stale' };
    return { value: null, state: 'miss' };
  } catch {
    return { value: null, state: 'miss' };
  }
}

export async function writeCache<T>(key: string, data: T, policy: CachePolicy): Promise<CachedValue<T>> {
  const now = Date.now();
  const value: CachedValue<T> = {
    data,
    fetchedAt: new Date(now).toISOString(),
    freshUntil: now + policy.freshSeconds * 1000,
    staleUntil: now + policy.staleSeconds * 1000,
  };

  const response = new Response(JSON.stringify(value), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': `max-age=${policy.staleSeconds}`,
    },
  });
  const cache = (caches as unknown as { default: Cache }).default;
  await cache.put(cacheRequest(key), response);
  return value;
}
