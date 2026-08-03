import 'package:dalil_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android and iOS use the same Firebase project', () {
    expect(
      DefaultFirebaseOptions.android.projectId,
      'gen-lang-client-0048255023',
    );
    expect(
      DefaultFirebaseOptions.ios.projectId,
      DefaultFirebaseOptions.android.projectId,
    );
    expect(
      DefaultFirebaseOptions.android.appId,
      startsWith('1:846312712628:android:'),
    );
    expect(
      DefaultFirebaseOptions.ios.appId,
      startsWith('1:846312712628:ios:'),
    );
  });
}
