import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:graphene_multicooker_app/features/auth/presentation/auth_scaffold.dart';

void main() {
  testWidgets('회원가입 화면의 시스템 뒤로가기는 로그인 화면으로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('로그인')),
        ),
        GoRoute(
          path: '/register',
          builder: (_, _) => const AuthScaffold(
            title: '회원가입',
            showBack: true,
            backPath: '/login',
            children: [Text('회원가입 화면')],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('비밀번호 재설정 화면의 시스템 뒤로가기는 로그인 화면으로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/reset',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('로그인')),
        ),
        GoRoute(
          path: '/reset',
          builder: (_, _) => const AuthScaffold(
            title: '비밀번호 재설정',
            showBack: true,
            backPath: '/login',
            children: [Text('비밀번호 재설정 화면')],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('로그인'), findsOneWidget);
  });
}
