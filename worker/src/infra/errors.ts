export type ErrorCode =
  | 'INVALID_STOP'
  | 'ROUTE_NOT_FOUND'
  | 'SOURCE_TIMEOUT'
  | 'SOURCE_UNAVAILABLE'
  | 'SOURCE_ACCESS_RESTRICTED'
  | 'SOURCE_INVALID_RESPONSE'
  | 'INTERNAL_ERROR';

export class AppError extends Error {
  constructor(
    public readonly code: ErrorCode,
    message: string,
    public readonly status: number,
    public readonly retryable: boolean,
    options?: ErrorOptions,
  ) {
    super(message, options);
    this.name = 'AppError';
  }
}
