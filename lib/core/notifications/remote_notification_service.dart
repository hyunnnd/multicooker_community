import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';
import 'runtime_firebase_options.dart';

@pragma('vm:entry-point')
Future<void> grapheneFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  final options = RuntimeFirebaseOptions.currentPlatform;
  if (options == null) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
}

/// FCM 기기 토큰 등록과 푸시 탭 이동을 담당합니다.
/// Firebase 값이 주입되지 않은 개발 빌드에서는 조용히 비활성화됩니다.
class RemoteNotificationService {
  RemoteNotificationService({
    required Dio dio,
    required LocalNotificationService localNotifications,
  })  : _dio = dio,
        _localNotifications = localNotifications;

  final Dio _dio;
  final LocalNotificationService _localNotifications;

  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  void Function(String route)? _onRouteRequested;
  Future<void> Function()? _onNotificationReceived;

  bool _initializationAttempted = false;
  bool _initialized = false;
  bool _registrationEnabled = false;
  String? _registeredToken;

  bool get isConfigured => RuntimeFirebaseOptions.currentPlatform != null;
  bool get isInitialized => _initialized;
  bool get isActive => _initialized && _registeredToken != null;

  Future<bool> initialize({
    void Function(String route)? onRouteRequested,
    Future<void> Function()? onNotificationReceived,
  }) async {
    _onRouteRequested = onRouteRequested ?? _onRouteRequested;
    _onNotificationReceived =
        onNotificationReceived ?? _onNotificationReceived;
    if (_initialized) return true;
    if (_initializationAttempted) return false;
    _initializationAttempted = true;

    final options = RuntimeFirebaseOptions.currentPlatform;
    if (options == null) return false;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      FirebaseMessaging.onBackgroundMessage(
        grapheneFirebaseMessagingBackgroundHandler,
      );
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _openedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        if (_registrationEnabled) {
          unawaited(_registerToken(token));
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        scheduleMicrotask(() => _handleOpenedMessage(initialMessage));
      }
      _initialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('FCM 초기화 실패: $error\n$stackTrace');
      return false;
    }
  }

  void setHandlers({
    void Function(String route)? onRouteRequested,
    Future<void> Function()? onNotificationReceived,
  }) {
    _onRouteRequested = onRouteRequested ?? _onRouteRequested;
    _onNotificationReceived =
        onNotificationReceived ?? _onNotificationReceived;
  }

  Future<void> syncRegistration({required bool enabled}) async {
    _registrationEnabled = enabled;
    if (!enabled) {
      await unregister();
      return;
    }
    if (!await initialize()) return;

    try {
      final token = await _messaging?.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error) {
      debugPrint('FCM 토큰 조회 실패: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    if (!_registrationEnabled || token.isEmpty || token == _registeredToken) {
      return;
    }
    try {
      await _dio.post(
        '/push/devices',
        data: {
          'token': token,
          'platform': switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            _ => 'other',
          },
        },
      );
      _registeredToken = token;
    } catch (error) {
      debugPrint('FCM 토큰 서버 등록 실패: $error');
    }
  }

  Future<void> unregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    if (!_initialized || token == null || token.isEmpty) return;
    try {
      await _dio.post('/push/devices/unregister', data: {'token': token});
    } catch (error) {
      debugPrint('FCM 토큰 해제 실패: $error');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        '새 알림';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';
    final route = message.data['route']?.toString() ?? '/community';
    final unreadCount = int.tryParse(
      message.data['unread_count']?.toString() ?? '',
    );

    await _localNotifications.showRemoteCommunityMessage(
      title: title,
      body: body,
      route: route,
      unreadCount: unreadCount,
    );
    await _onNotificationReceived?.call();
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final route = message.data['route']?.toString();
    if (route == null || route.trim().isEmpty) return;
    _onRouteRequested?.call(route);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
