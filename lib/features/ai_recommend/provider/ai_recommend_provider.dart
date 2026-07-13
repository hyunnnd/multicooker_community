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
