import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/ai_recommend_repository.dart';
import '../data/ai_recommend_result.dart';

class AiRecommendProvider extends ChangeNotifier {
  AiRecommendProvider(this.repository);

  final AiRecommendRepository repository;

  bool isLoading = false;
  String? errorMessage;
  AiRecommendResult? result;

  Future<bool> analyzeImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      result = await repository.analyzeImage(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
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
