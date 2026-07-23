// Firebase configuration for the "remedly-86882" project.
//
// Android values are the REAL project values (mirrored from
// android/app/google-services.json). iOS values point at the same project but
// are a BEST-EFFORT stand-in: this project currently has NO registered iOS app
// (google-services.json contains only Android + web OAuth clients), so the iOS
// `appId` below is a placeholder and Google Sign-In on iOS will not work until
// an iOS app is registered. To fix iOS properly, run `flutterfire configure`
// (or add an iOS app with bundle `com.implementation.tabletremainder.tabletRemainder`
// to the Firebase console, download GoogleService-Info.plist into ios/Runner/,
// and add its REVERSED_CLIENT_ID as a URL scheme in ios/Runner/Info.plist).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Real values — mirrored from android/app/google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCL3QZk5VXByMc3vpfNdyVWwTqrnkKaekk',
    appId: '1:393292496655:android:98cbb11f06b64d66c5c87a',
    messagingSenderId: '393292496655',
    projectId: 'remedly-86882',
    storageBucket: 'remedly-86882.firebasestorage.app',
  );

  // Same project; iOS app not yet registered → appId is a stand-in (see header).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCL3QZk5VXByMc3vpfNdyVWwTqrnkKaekk',
    appId: '1:393292496655:ios:98cbb11f06b64d66c5c87a',
    messagingSenderId: '393292496655',
    projectId: 'remedly-86882',
    iosBundleId: 'com.implementation.tabletremainder.tabletRemainder',
    storageBucket: 'remedly-86882.firebasestorage.app',
  );
}
