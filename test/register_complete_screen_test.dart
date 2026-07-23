import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphene_multicooker_app/core/storage/secure_token_storage.dart';
import 'package:graphene_multicooker_app/features/auth/data/auth_api.dart';
import 'package:graphene_multicooker_app/features/auth/data/auth_repository.dart';
import 'package:graphene_multicooker_app/features/auth/presentation/register_complete_screen.dart';
import 'package:graphene_multicooker_app/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('가입 완료의 빈 이메일 안내는 반복 표시된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dio = Dio();
    final auth = AuthProvider(
      AuthRepository(AuthApi(dio), LocalAuthApi(dio), SecureTokenStorage()),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: RegisterCompleteScreen()),
      ),
    );

    await tester.tap(find.text('가입 완료'));
    await tester.pump();
    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);

    await tester.tap(find.text('가입 완료'));
    await tester.pump();
    expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
  });
}
