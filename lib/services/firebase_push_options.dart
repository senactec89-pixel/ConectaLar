import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class FirebasePushOptions {
  static const enabled = bool.fromEnvironment('CONECTALAR_FCM_ENABLED');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static FirebaseOptions? get currentPlatform {
    if (!enabled || projectId.isEmpty || messagingSenderId.isEmpty) return null;

    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android
          when androidAppId.isNotEmpty && androidApiKey.isNotEmpty =>
        FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
        ),
      TargetPlatform.iOS
          when iosAppId.isNotEmpty &&
              iosApiKey.isNotEmpty &&
              iosBundleId.isNotEmpty =>
        FirebaseOptions(
          apiKey: iosApiKey,
          appId: iosAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          iosBundleId: iosBundleId,
        ),
      _ => null,
    };
  }
}
