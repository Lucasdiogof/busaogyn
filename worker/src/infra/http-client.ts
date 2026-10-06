import { AppError } from './errors';

export interface FetchPolicy {
  timeoutMs: number;
  retries?: number;
}

const RETRYABLE_STATUS = new Set([502, 503, 504]);

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchWithPolicy(
  input: RequestInfo | URL,
  init: RequestInit,
  policy: FetchPolicy,
): Promise<Response> {
  const retries = policy.retries ?? 1;
  let lastError: unknown;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), policy.timeoutMs);

    try {
      const response = await fetch(input, { ...init, signal: controller.signal });
      if (RETRYABLE_STATUS.has(response.status) && attempt < retries) {
        await delay(200 * (attempt + 1));
        continue;
      }
      return response;
    } catch (error) {
      lastError = error;
      if (error instanceof DOMException && error.name === 'AbortError') {
        if (attempt >= retries) {
          throw new AppError('SOURCE_TIMEOUT', 'Upstream source timed out.', 503, true, { cause: error });
        }
      } else if (attempt >= retries) {
        throw new AppError('SOURCE_UNAVAILABLE', 'Upstream source is unavailable.', 503, true, { cause: error });
      }
      await delay(200 * (attempt + 1));
    } finally {
      clearTimeout(timeout);
    }
  }

  throw new AppError('SOURCE_UNAVAILABLE', 'Upstream source is unavailable.', 503, true, { cause: lastError });
}
