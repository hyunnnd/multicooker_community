import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import 'ai_recommend_result.dart';

class AiRecommendRepository {
  AiRecommendRepository(this._dio);

  final Dio _dio;
  Map<String, dynamic>? lastUploadInfo;

  Future<Map<String, dynamic>> requestUploadUrl({
    required String filename,
    String contentType = 'image/png',
  }) async {
    final response = await _dio.post(
      ApiConstants.aiUploadPhoto,
      data: {'filename': filename, 'content_type': contentType},
    );
    final upload = Map<String, dynamic>.from(response.data as Map);
    lastUploadInfo = upload;
    debugPrint('AI upload presigned info: $upload');
    return upload;
  }

  Future<AiRecommendResult> completeUpload({
    required String s3Key,
    String? imageUrl,
    String? originalFilename,
    String? contentType,
  }) async {
    final response = await _dio.post(
      ApiConstants.aiUploadComplete,
      data: {
        's3_key': s3Key,
        'image_url': imageUrl,
        'original_filename': originalFilename,
        'content_type': contentType,
      },
    );
    return AiRecommendResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AiRecommendResult> analyzeImage({
    required String filePath,
    required String filename,
    required String contentType,
  }) async {
    final upload = await requestUploadUrl(
      filename: filename,
      contentType: contentType,
    );
    final file = File(filePath);
    final headers = Map<String, dynamic>.from(
      (upload['headers'] as Map?) ?? const {},
    );
    headers[Headers.contentLengthHeader] = await file.length();

    await Dio().put<void>(
      upload['upload_url'] as String,
      data: file.openRead(),
      options: Options(headers: headers, contentType: contentType),
    );

    return completeUpload(
      s3Key: upload['s3_key'] as String,
      imageUrl: upload['image_url'] as String?,
      originalFilename: filename,
      contentType: contentType,
    );
  }
}
