export interface ServiceResult<T> {
  data: T;
  fetchedAt: string;
  cache: 'HIT' | 'MISS' | 'STALE';
  stale: boolean;
  ageSeconds: number;
}
