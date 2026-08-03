final class Environment {
  Environment._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static Uri get apiV2 => Uri.parse('$apiBaseUrl/api/v2/');
}
