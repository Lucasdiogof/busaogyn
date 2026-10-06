export function logEvent(event: Record<string, unknown>): void {
  console.log(JSON.stringify({ service: 'busaogyn-api', ...event }));
}
