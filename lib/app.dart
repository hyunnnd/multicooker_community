import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/notifications/local_notification_service.dart';
import 'core/notifications/remote_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/router/authenticated_landing_route.dart';
import 'core/widgets/app_toast.dart';
import 'core/widgets/global_cooker_overlay.dart';
import 'features/auth/data/google_auth_callback.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/community/data/models/community_models.dart';
import 'features/community/provider/community_provider.dart';
import 'features/cooking/data/models/cooking_session_state.dart';
import 'features/cooking/provider/cooking_session_provider.dart';
import 'features/device/provider/device_provider.dart';
import 'features/profile/provider/profile_provider.dart';
import 'features/recipe/provider/recipe_provider.dart';

class GrapheneMultiCookerApp extends StatefulWidget {
  const GrapheneMultiCookerApp({super.key});

  @override
  State<GrapheneMultiCookerApp> createState() =>
      _GrapheneMultiCookerAppState();
}

class _GrapheneMultiCookerAppState extends State<GrapheneMultiCookerApp>
    with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final Set<String> _handledGoogleCallbacks = <String>{};

  StreamSubscription<Uri>? _linkSubscription;
  bool _googleCallbackInProgress = false;
  bool _accountScopeInitialized = false;
  String? _activeAccountEmail;
  bool _activeLocalApiReady = false;

  CommunityProvider? _communityProvider;
  ProfileProvider? _profileProvider;
  CookingSessionProvider? _cookingProvider;
  DeviceProvider? _deviceProvider;
  LocalNotificationService? _notificationService;
  RemoteNotificationService? _remoteNotificationService;
  Timer? _notificationPollTimer;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  CookingPhase? _lastCookingPhase;
  bool _reconnectNotificationVisible = false;
  bool _behaviorSyncScheduled = false;
  bool _behaviorSyncRunning = false;
  bool _behaviorSyncPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _notificationPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollNotifications(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindBehaviorProviders();
  }

  void _bindBehaviorProviders() {
    final community = context.read<CommunityProvider>();
    final profile = context.read<ProfileProvider>();
    final cooking = context.read<CookingSessionProvider>();
    final device = context.read<DeviceProvider>();
    final notifications = context.read<LocalNotificationService>();
    final remoteNotifications = context.read<RemoteNotificationService>();

    if (identical(_communityProvider, community) &&
        identical(_profileProvider, profile) &&
        identical(_cookingProvider, cooking) &&
        identical(_deviceProvider, device) &&
        identical(_remoteNotificationService, remoteNotifications)) {
      return;
    }

    _communityProvider?.removeListener(_scheduleBehaviorSync);
    _profileProvider?.removeListener(_scheduleBehaviorSync);
    _cookingProvider?.removeListener(_scheduleBehaviorSync);
    _deviceProvider?.removeListener(_scheduleBehaviorSync);

    _communityProvider = community..addListener(_scheduleBehaviorSync);
    _profileProvider = profile..addListener(_scheduleBehaviorSync);
    _cookingProvider = cooking..addListener(_scheduleBehaviorSync);
    _deviceProvider = device..addListener(_scheduleBehaviorSync);
    _notificationService = notifications;
    _remoteNotificationService = remoteNotifications;
    remoteNotifications.setHandlers(
      onRouteRequested: (route) {
        if (route.trim().isNotEmpty) appRouter.go(route);
      },
      onNotificationReceived: () async {
        if (!mounted) return;
        await context
            .read<CommunityProvider>()
            .refreshNotifications(silent: true);
      },
    );
    _scheduleBehaviorSync();
  }

  void _scheduleBehaviorSync() {
    if (!mounted || _behaviorSyncScheduled) return;
    _behaviorSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _behaviorSyncScheduled = false;
      if (mounted) unawaited(_syncBehaviorNotifications());
    });
  }

  Future<void> _pollNotifications() async {
    if (!mounted || _lifecycleState != AppLifecycleState.resumed) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || !auth.localApiReady) return;
    await context.read<CommunityProvider>().refreshNotifications(silent: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(_pollNotifications());
      _scheduleBehaviorSync();
    }
  }

  Future<void> _syncBehaviorNotifications() async {
    if (_behaviorSyncRunning) {
      _behaviorSyncPending = true;
      return;
    }

    _behaviorSyncRunning = true;
    try {
      do {
        _behaviorSyncPending = false;
        await _syncBehaviorNotificationsOnce();
      } while (_behaviorSyncPending && mounted);
    } finally {
      _behaviorSyncRunning = false;
    }
  }

  Future<void> _syncBehaviorNotificationsOnce() async {
    final community = _communityProvider;
    final profile = _profileProvider;
    final cooking = _cookingProvider;
    final device = _deviceProvider;
    final notifications = _notificationService;
    final remoteNotifications = _remoteNotificationService;
    if (community == null ||
        profile == null ||
        cooking == null ||
        device == null ||
        notifications == null ||
        remoteNotifications == null ||
        !mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      _lastCookingPhase = cooking.state.phase;
      _reconnectNotificationVisible = false;
      await remoteNotifications.syncRegistration(enabled: false);
      await notifications.cancelAllAppBehaviorNotifications();
      return;
    }

    final settings = profile.settings;
    device.setAutoReconnectEnabled(settings.autoReconnect);

    final email = auth.currentEmail?.trim().toLowerCase() ?? '';
    await remoteNotifications.syncRegistration(
      enabled: settings.communityNotification && auth.localApiReady,
    );

    if (remoteNotifications.isActive) {
      // 원격 푸시가 설정된 빌드에서는 서버가 새 이벤트 생성 시 한 번만
      // FCM을 전송합니다. 앱 재실행 시 기존 미확인 목록을 다시 울리지 않습니다.
      await notifications.cancelCommunitySummary(
        accountEmail: email,
        resetState: false,
      );
    } else if (settings.communityNotification) {
      // Firebase 값이 없는 개발 빌드에서만 앱 실행 중 폴링 알림을 사용합니다.
      bool notificationEnabled(CommunityNotification notification) {
        return switch (notification.type) {
          NotificationType.comment => settings.commentNotification,
          NotificationType.recipeComment => settings.commentNotification,
          NotificationType.recipeReview => settings.commentNotification,
          NotificationType.reply => settings.replyNotification,
          NotificationType.like => settings.likeNotification,
          NotificationType.notice => settings.noticeNotification,
        };
      }

      final unread = community.notifications
          .where(
            (notification) =>
                !notification.read && notificationEnabled(notification),
          )
          .toList(growable: false)
        ..sort((a, b) => b.id.compareTo(a.id));
      if (unread.isNotEmpty && email.isNotEmpty) {
        await notifications.showCommunitySummary(
          accountEmail: email,
          latest: unread.first,
          unreadCount: unread.length,
        );
      } else {
        await notifications.cancelCommunitySummary(
          accountEmail: email,
          resetState: false,
        );
      }
    } else {
      await notifications.cancelCommunitySummary(
        accountEmail: email,
        resetState: false,
      );
    }

    final phase = cooking.state.phase;
    if (settings.cookingNotification && phase != _lastCookingPhase) {
      if (phase == CookingPhase.preheatReady) {
        await notifications.showPreheatComplete();
      } else if (phase == CookingPhase.completed) {
        await notifications.showCookingComplete();
      }
    }
    if (!settings.cookingNotification) {
      await notifications.cancelCookingAlerts();
    }
    _lastCookingPhase = phase;

    final shouldShowReconnect =
        settings.autoReconnect && device.reconnectingAfterLoss;
    if (shouldShowReconnect && !_reconnectNotificationVisible) {
      _reconnectNotificationVisible = true;
      await notifications.showReconnecting(deviceName: device.lastConnectedName);
    } else if (!shouldShowReconnect && _reconnectNotificationVisible) {
      _reconnectNotificationVisible = false;
      await notifications.cancelReconnecting();
    }
  }

  Future<void> _initDeepLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _scheduleDeepLink,
      onError: (_) => _showMessage('앱으로 돌아오는 링크를 처리하지 못했습니다.'),
    );

    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) _scheduleDeepLink(initialLink);
    } catch (_) {
      _showMessage('초기 로그인 링크를 확인하지 못했습니다.');
    }
  }

  void _scheduleDeepLink(Uri uri) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (!GoogleAuthCallback.matches(uri)) return;

    final callbackKey = uri.toString();
    if (_handledGoogleCallbacks.contains(callbackKey) ||
        _googleCallbackInProgress) {
      return;
    }
    _handledGoogleCallbacks.add(callbackKey);

    final callback = GoogleAuthCallback.fromUri(uri);
    if (callback.hasError) {
      appRouter.go('/login');
      _showMessage(_googleErrorMessage(callback.error!));
      return;
    }
    if (!callback.hasCode) {
      appRouter.go('/login');
      _showMessage('구글 로그인 코드가 전달되지 않았습니다.');
      return;
    }

    _googleCallbackInProgress = true;
    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithGoogleCode(callback.code!);
    _googleCallbackInProgress = false;

    if (!mounted) return;
    if (success) {
      final route = await resolveAuthenticatedLandingRoute(
        context,
        forceTutorial: callback.isRegistration,
      );
      if (!mounted) return;
      appRouter.go(route);
      _showMessage(
        callback.isRegistration
            ? '구글 계정으로 회원가입되었습니다.'
            : '구글 계정으로 로그인되었습니다.',
        success: true,
      );
      return;
    }

    appRouter.go('/login');
    _showMessage(auth.errorMessage ?? '구글 로그인에 실패했습니다.');
  }

  String _googleErrorMessage(String error) {
    return switch (error) {
      'google_login_failed' => '구글 계정 인증에 실패했습니다.',
      'user_auth_failed' =>
        'Google 인증 서버에서 사용자 계정을 처리하지 못했습니다. '
        '동일 이메일의 기존 계정 연동 또는 중복 계정 처리 여부를 서버에서 확인해 주세요.',
      'duplicate_email' =>
        '같은 이메일로 가입된 기존 계정이 있습니다. '
        'Google 계정과 기존 계정을 서버에서 연동해야 합니다.',
      _ => '구글 로그인에 실패했습니다.',
    };
  }

  void _syncAccountScopedState(AuthProvider auth) {
    final nextEmail = auth.isAuthenticated
        ? auth.currentEmail?.trim().toLowerCase()
        : null;
    final accountChanged =
        !_accountScopeInitialized || _activeAccountEmail != nextEmail;
    final localReadinessChanged =
        !accountChanged && _activeLocalApiReady != auth.localApiReady;
    if (!accountChanged && !localReadinessChanged) return;

    _accountScopeInitialized = true;
    _activeAccountEmail = nextEmail;
    _activeLocalApiReady = auth.localApiReady;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (accountChanged) {
        context.read<RecipeProvider>().resetForAccountChange();
        context.read<ProfileProvider>().resetForAccountChange();
        context.read<CommunityProvider>().resetForAccountChange();
      }
      if (nextEmail != null &&
          nextEmail.isNotEmpty &&
          auth.localApiReady) {
        unawaited(context.read<RecipeProvider>().loadRecipes());
        unawaited(context.read<ProfileProvider>().loadOverview());
        unawaited(context.read<CommunityProvider>().load(silent: true));
      }
    });
  }

  void _showMessage(String message, {bool success = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(appToast(message, success: success));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationPollTimer?.cancel();
    _communityProvider?.removeListener(_scheduleBehaviorSync);
    _profileProvider?.removeListener(_scheduleBehaviorSync);
    _cookingProvider?.removeListener(_scheduleBehaviorSync);
    _deviceProvider?.removeListener(_scheduleBehaviorSync);
    _linkSubscription?.cancel();
    unawaited(_remoteNotificationService?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    _syncAccountScopedState(auth);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListenableBuilder(
          listenable: appRouter.routeInformationProvider,
          builder: (context, _) {
            final uri = appRouter.routeInformationProvider.value.uri;
            return GlobalCookerOverlay(
              currentPath: uri.path,
              hidePet: uri.path.startsWith('/tutorial/'),
              onOpenCooking: (recipeId) =>
                  appRouter.go('/recipes/$recipeId/cook'),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3378C0),
          primary: const Color(0xFF3378C0),
          error: const Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF111827),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF97316)),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.white,
          elevation: 4,
          insetPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          contentTextStyle: const TextStyle(
            color: Color(0xFF374151),
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
