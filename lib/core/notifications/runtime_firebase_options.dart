import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase CLI 파일을 저장소에 넣지 않고도 빌드 환경별 값을 주입할 수 있게 합니다.
/// 필수 값이 하나라도 비어 있으면 원격 푸시는 비활성화되고 기존 앱 기능은 유지됩니다.
abstract final class RuntimeFirebaseOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;

    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidAppId,
      TargetPlatform.iOS => _iosAppId,
      _ => '',
    };
    if (_apiKey.isEmpty ||
        _projectId.isEmpty ||
        _senderId.isEmpty ||
        appId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS &&
              _iosBundleId.isNotEmpty
          ? _iosBundleId
          : null,
    );
  }
}
