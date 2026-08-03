import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

final class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is configured only for Android and iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGTuT4XPF_j0WuwDhPvKX2XLqh2_kWSz4',
    appId: '1:846312712628:android:3dce513925a951fb152ae1',
    messagingSenderId: '846312712628',
    projectId: 'gen-lang-client-0048255023',
    storageBucket: 'gen-lang-client-0048255023.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCcIEjynzyOvYu8aO0s28SXenNITjeRxHU',
    appId: '1:846312712628:ios:d2ad0a9501196206152ae1',
    messagingSenderId: '846312712628',
    projectId: 'gen-lang-client-0048255023',
    storageBucket: 'gen-lang-client-0048255023.firebasestorage.app',
    iosBundleId: 'com.daliilaykhidma.dalilApp',
  );
}

