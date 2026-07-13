import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/widgets/global_cooker_overlay.dart';
import 'features/auth/data/google_auth_callback.dart';
import 'features/auth/provider/auth_provider.dart';

class GrapheneMultiCookerApp extends StatefulWidget {
  const GrapheneMultiCookerApp({super.key});

  @override
  State<GrapheneMultiCookerApp> createState() =>
      _GrapheneMultiCookerAppState();
}

class _GrapheneMultiCookerAppState extends State<GrapheneMultiCookerApp> {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final Set<String> _handledGoogleCallbacks = <String>{};

  StreamSubscription<Uri>? _linkSubscription;
  bool _googleCallbackInProgress = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
      appRouter.go('/home');
      _showMessage(
        callback.isRegistration
            ? '구글 계정으로 회원가입되었습니다.'
            : '구글 계정으로 로그인되었습니다.',
      );
      return;
    }

    appRouter.go('/login');
    _showMessage(auth.errorMessage ?? '구글 로그인에 실패했습니다.');
  }

  String _googleErrorMessage(String error) {
    return switch (error) {
      'google_login_failed' => '구글 계정 인증에 실패했습니다.',
      'user_auth_failed' => '사용자 계정을 처리하지 못했습니다.',
      _ => '구글 로그인에 실패했습니다.',
    };
  }

  void _showMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      builder: (context, child) => ListenableBuilder(
        listenable: appRouter.routeInformationProvider,
        builder: (context, _) => GlobalCookerOverlay(
          currentPath: appRouter.routeInformationProvider.value.uri.path,
          onOpenCooking: (recipeId) => appRouter.go('/recipes/$recipeId/cook'),
          child: child ?? const SizedBox.shrink(),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
