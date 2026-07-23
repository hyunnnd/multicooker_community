import 'package:flutter/foundation.dart';

import '../data/ai_recommend_repository.dart';
import '../data/ai_recommend_result.dart';

class AiRecommendProvider extends ChangeNotifier {
  AiRecommendProvider(this.repository);

  final AiRecommendRepository repository;

  bool isLoading = false;
  String? errorMessage;
  AiRecommendResult? result;
  Map<String, dynamic>? lastUploadInfo;
  final recommendationHistory = <AiRecommendedRecipe>[];

  Future<bool> analyzeImage({
    required String filePath,
    required String filename,
    required String contentType,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      result = await repository.analyzeImage(
        filePath: filePath,
        filename: filename,
        contentType: contentType,
      );
      recommendationHistory.removeWhere(
        (item) => result!.recipes.any((recipe) => recipe.title == item.title),
      );
      recommendationHistory.insertAll(0, result!.recipes);
      if (recommendationHistory.length > 6) {
        recommendationHistory.removeRange(6, recommendationHistory.length);
      }
      lastUploadInfo = repository.lastUploadInfo;
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
