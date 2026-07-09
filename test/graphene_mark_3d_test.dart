import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphene_multicooker_app/core/widgets/graphene_mark_3d.dart';

void main() {
  testWidgets('3D 로고가 위에서 떨어져 반동한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GrapheneMark3D(size: 100))),
    );

    final logo = find.byType(GrapheneMark3D);
    final transforms = find.descendant(
      of: logo,
      matching: find.byType(Transform),
    );
    final before = tester
        .widgetList<Transform>(transforms)
        .last
        .transform
        .storage
        .toList();

    await tester.pump(const Duration(milliseconds: 600));

    final after = tester
        .widgetList<Transform>(transforms)
        .last
        .transform
        .storage
        .toList();
    expect(
      find.descendant(of: logo, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(after, isNot(before));
  });
}
