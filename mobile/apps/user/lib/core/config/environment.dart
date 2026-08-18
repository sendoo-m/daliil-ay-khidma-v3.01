final class Environment {
  Environment._();

  /// Production is the safe default for distributed builds.
  /// Local development can still override with:
  /// --dart-define=API_BASE_URL=http://10.0.2.2:8000
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://daliil-ay-khidma.onrender.com',
  );

  static Uri get apiV2 => Uri.parse('$apiBaseUrl/api/v2/');
}
