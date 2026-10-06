final class AppConfig {
  const AppConfig({
    required this.apiBaseUri,
  });

  final Uri apiBaseUri;

  factory AppConfig.fromEnvironment() {
    const rawBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8787',
    );

    final uri = Uri.parse(rawBaseUrl);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL must be an absolute URL.');
    }

    return AppConfig(apiBaseUri: uri);
  }
}
