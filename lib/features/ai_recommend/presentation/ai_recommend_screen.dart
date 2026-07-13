import 'package:flutter/material.dart';

import '../../../core/widgets/main_navigation.dart';

class AiRecommendScreen extends StatelessWidget {
  const AiRecommendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton()),
      bottomNavigationBar: const MainNavigationBar(currentIndex: -1),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '식재료 사진 업로드 URL 요청 API 뼈대만 준비했습니다. 카메라/AI 결과 UI는 다음 단계입니다.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
