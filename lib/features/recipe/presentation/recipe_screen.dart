import 'package:flutter/material.dart';

import '../../../core/widgets/main_navigation.dart';

class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton()),
      bottomNavigationBar: const MainNavigationBar(currentIndex: 1),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '레시피 목록/검색은 다음 단계에서 /recipe API와 연결합니다.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
