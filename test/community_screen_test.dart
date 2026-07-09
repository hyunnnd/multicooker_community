import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphene_multicooker_app/features/community/presentation/community_screen.dart';

void main() {
  testWidgets('커뮤니티 필터와 좋아요가 동작한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));

    expect(find.text('첫 그래핀 솥밥, 누룽지까지 성공했어요'), findsOneWidget);

    await tester.tap(find.text('질문'));
    await tester.pump();
    expect(find.text('계란찜은 중간에 뚜껑을 열어도 될까요?'), findsOneWidget);
    expect(find.text('첫 그래핀 솥밥, 누룽지까지 성공했어요'), findsNothing);

    await tester.tap(find.text('전체'));
    await tester.pump();
    final likeButton = find.byIcon(Icons.favorite_border).first;
    await tester.ensureVisible(likeButton);
    await tester.pumpAndSettle();
    await tester.tap(likeButton);
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
}
