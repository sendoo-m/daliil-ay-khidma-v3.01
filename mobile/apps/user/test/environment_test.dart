import 'package:dalil_app/core/config/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API v2 URL is derived from the configured base URL', () {
    expect(Environment.apiV2.path, '/api/v2/');
  });
}
