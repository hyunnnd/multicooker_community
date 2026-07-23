import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphene_multicooker_app/core/widgets/spotlight_tutorial.dart';

void main() {
  testWidgets('Spotlight 튜토리얼은 실제 대상과 다음 단계를 표시한다', (tester) async {
    final first = GlobalKey();
    final second = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(key: first, width: 200, height: 48),
              ),
              Align(
                alignment: Alignment.center,
                child: SizedBox(key: second, width: 200, height: 48),
              ),
              SpotlightTutorial(
                steps: [
                  SpotlightTutorialStep(
                    targetKey: first,
                    title: '쿠커 연결',
                    description: '기기를 연결해요.',
                  ),
                  SpotlightTutorialStep(
                    targetKey: second,
                    title: 'AI 추천',
                    description: '재료로 레시피를 찾아요.',
                  ),
                ],
                onComplete: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('쿠커 연결'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('AI 추천'), findsOneWidget);
  });
}
