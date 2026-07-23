import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/community/data/models/community_models.dart';
import '../storage/secure_token_storage.dart';

/// 휴대전화 알림 표시를 한 곳에서 관리합니다.
///
/// 커뮤니티/레시피 알림은 같은 notification id를 계속 사용하므로 알림 창에는
/// 최신 알림 한 건만 남고, 읽지 않은 전체 개수는 숫자로 표시됩니다.
class LocalNotificationService {
  LocalNotificationService(this._storage);

  static const int communitySummaryId = 1001;
  static const int preheatCompleteId = 2001;
  static const int cookingCompleteId = 2002;
  static const int reconnectingId = 3001;

  final SecureTokenStorage _storage;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String route)? _onRouteRequested;
  bool _initialized = false;
  bool? _permissionGranted;

  Future<void> initialize({void Function(String route)? onRouteRequested}) async {
    if (_initialized) {
      _onRouteRequested = onRouteRequested ?? _onRouteRequested;
      return;
    }
    _onRouteRequested = onRouteRequested;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleResponse,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'community_summary',
        '레시피 및 커뮤니티 알림',
        description: '레시피 후기, 댓글 및 커뮤니티 답글 알림',
        importance: Importance.high,
      ),
    );
    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      scheduleMicrotask(() => _onRouteRequested?.call(payload));
    }
  }

  void setRouteHandler(void Function(String route) handler) {
    _onRouteRequested = handler;
  }

  void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _onRouteRequested?.call(payload);
  }

  Future<bool> requestPermission({bool force = false}) async {
    if (!force && _permissionGranted != null) return _permissionGranted!;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 지원 플랫폼에서 하나라도 명시적으로 거절된 경우 false로 처리합니다.
    _permissionGranted = androidGranted != false && iosGranted != false;
    return _permissionGranted!;
  }

  Future<void> showCommunitySummary({
    required String accountEmail,
    required CommunityNotification latest,
    required int unreadCount,
  }) async {
    if (unreadCount > 0 && !await requestPermission()) return;
    if (unreadCount <= 0) {
      await cancelCommunitySummary(
        accountEmail: accountEmail,
        resetState: false,
      );
      return;
    }

    final lastId = await _storage.readLastCommunityNotificationId(accountEmail);

    // 휴대전화 알림은 서버에 새 알림 행이 생성됐을 때 한 번만 표시합니다.
    // 사용자가 알림 한 건을 읽어 unreadCount만 줄어든 경우에는 같은 알림을
    // 다시 생성하지 않습니다.
    if (lastId != null && latest.id <= lastId) return;

    const isNewNotification = true;
    final body = latest.postContextText;
    final title = latest.phoneMessage;
    final route = latest.routePath;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'community_summary',
        '레시피 및 커뮤니티 알림',
        channelDescription: '댓글, 답글, 좋아요, 후기 및 공지사항 알림',
        importance: Importance.high,
        priority: Priority.high,
        // 새 알림일 때만 소리/진동을 다시 발생시키고, 읽음 수 변경은
        // 같은 알림 카드의 숫자만 조용히 갱신합니다.
        onlyAlertOnce: !isNewNotification,
        number: unreadCount,
        subText: '$unreadCount개 알림',
        category: AndroidNotificationCategory.social,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: isNewNotification,
        badgeNumber: unreadCount,
        threadIdentifier: 'community_summary',
      ),
    );

    await _plugin.show(
      id: communitySummaryId,
      title: title,
      body: body.isEmpty ? latest.postTitle : body,
      notificationDetails: details,
      payload: route,
    );
    await _storage.saveCommunityNotificationState(
      email: accountEmail,
      id: latest.id,
      unreadCount: unreadCount,
    );
  }

  Future<void> showRemoteCommunityMessage({
    required String title,
    required String body,
    required String route,
    int? unreadCount,
  }) async {
    if (!await requestPermission()) return;
    await _plugin.show(
      id: communitySummaryId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'community_summary',
          '레시피 및 커뮤니티 알림',
          channelDescription: '댓글, 답글, 좋아요, 후기 및 공지사항 알림',
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: false,
          number: unreadCount,
          subText: unreadCount == null ? null : '$unreadCount개 알림',
          category: AndroidNotificationCategory.social,
        ),
        iOS: DarwinNotificationDetails(
          badgeNumber: unreadCount,
          threadIdentifier: 'community_summary',
        ),
      ),
      payload: route,
    );
  }

  Future<void> showPreheatComplete() async {
    if (!await requestPermission()) return;
    await _plugin.show(
      id: preheatCompleteId,
      title: '예열 완료',
      body: '멀티쿠커 예열이 완료되었습니다.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cooking_alerts',
          '조리 알림',
          channelDescription: '예열 및 조리 완료 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '/cooking',
    );
  }

  Future<void> showCookingComplete() async {
    if (!await requestPermission()) return;
    await _plugin.show(
      id: cookingCompleteId,
      title: '조리 완료',
      body: '멀티쿠커 조리가 완료되었습니다.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cooking_alerts',
          '조리 알림',
          channelDescription: '예열 및 조리 완료 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: '/cooking/complete',
    );
  }

  Future<void> showReconnecting({String? deviceName}) async {
    if (!await requestPermission()) return;
    await _plugin.show(
      id: reconnectingId,
      title: '쿠커 재연결 중',
      body:
          '${deviceName?.trim().isNotEmpty == true ? deviceName : '멀티쿠커'} 연결을 다시 시도하고 있습니다.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cooker_connection',
          '쿠커 연결 상태',
          channelDescription: '쿠커 연결 해제 및 자동 재연결 상태',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          category: AndroidNotificationCategory.progress,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: false,
          threadIdentifier: 'cooker_connection',
        ),
      ),
      payload: '/device',
    );
  }

  Future<void> cancelCommunitySummary({
    String? accountEmail,
    bool resetState = false,
  }) async {
    await _plugin.cancel(id: communitySummaryId);
    if (resetState && accountEmail?.trim().isNotEmpty == true) {
      await _storage.clearCommunityNotificationState(accountEmail!);
    }
  }

  Future<void> cancelReconnecting() => _plugin.cancel(id: reconnectingId);
  Future<void> cancelCookingAlerts() async {
    await _plugin.cancel(id: preheatCompleteId);
    await _plugin.cancel(id: cookingCompleteId);
  }

  Future<void> cancelAllAppBehaviorNotifications() async {
    await cancelCommunitySummary();
    await cancelReconnecting();
    await cancelCookingAlerts();
  }
}
