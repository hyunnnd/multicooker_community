import 'package:flutter_test/flutter_test.dart';
import 'package:graphene_multicooker_app/features/ai_recommend/data/ai_recommend_result.dart';

void main() {
  test('AI 추천 API 응답을 식재료와 레시피로 변환한다', () {
    final result = AiRecommendResult.fromJson({
      'photo_url': 'https://example.com/ingredients/test.jpg',
      'ingredients': [
        {'name': '닭고기', 'confidence': 0.94, 'bbox': {}},
      ],
      'recipes': [
        {
          'title': '닭고기 볶음',
          'description': '간단한 볶음 요리',
          'similarity': 0.92,
          'steps': [
            {'temperature': 180, 'time_offset': 0},
            {'temperature': 200, 'time_offset': 300},
          ],
        },
      ],
    });

    expect(result.ingredients.single.name, '닭고기');
    expect(result.recipes.single.similarity, 0.92);
    expect(result.recipes.single.steps.last.timeOffset, 300);
  });
}
