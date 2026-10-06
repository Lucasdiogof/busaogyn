abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'BUSAOGYN_API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );
}
