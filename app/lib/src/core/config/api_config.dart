abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'BUSAOGYN_API_BASE_URL',
    defaultValue: 'https://busaogyn-api.lively-cloud-f009.workers.dev',
  );
}
