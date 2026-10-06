export function asNonEmptyString(value: unknown): string | null {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value);
  }
  return null;
}

export function normalizeRouteId(value: unknown): string | null {
  const raw = asNonEmptyString(value);
  if (raw === null) return null;
  if (/^\d{1,3}$/.test(raw)) return raw.padStart(3, '0');
  return raw;
}

export function normalizeStopId(value: string): string | null {
  const raw = value.trim();
  return /^\d+$/.test(raw) ? raw : null;
}

export function parseBoolean(value: unknown): boolean | null {
  if (typeof value === 'boolean') return value;
  if (value === 1 || value === '1') return true;
  if (value === 0 || value === '0') return false;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === 'sim') return true;
    if (normalized === 'false' || normalized === 'nao' || normalized === 'não') return false;
  }
  return null;
}

export function parseCoordinate(value: unknown, min: number, max: number): number | null {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) return null;
  return parsed;
}

export function parseNonNegativeInteger(value: unknown): number | null {
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) return null;
  return parsed;
}
