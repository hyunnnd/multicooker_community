import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:graphene_multicooker_app/core/widgets/main_navigation.dart';

void main() {
  testWidgets('홈은 5개 메뉴의 중앙이고 탭으로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        for (final path in [
          '/ai-scan',
          '/recipes',
          '/home',
          '/device',
          '/settings',
        ])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(
              body: Text(state.uri.path),
              bottomNavigationBar: const MainNavigationBar(currentIndex: 2),
            ),
          ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();
    expect(labels, ['AI', '레시피', '홈', '기기', '설정']);

    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(find.text('/ai-scan'), findsOneWidget);
  });
}
