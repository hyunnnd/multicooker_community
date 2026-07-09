import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'ai_recommend_result.dart';

class AiRecommendRepository {
  AiRecommendRepository(this._dio) : _uploadDio = Dio();

  final Dio _dio;
  final Dio _uploadDio;

  Future<Map<String, dynamic>> requestUploadUrl({
    required String filename,
    String contentType = 'image/png',
  }) async {
    final response = await _dio.post(
      ApiConstants.aiUploadPhoto,
      data: {'filename': filename, 'content_type': contentType},
    );
    return Map<String, dynamic>.from(response.data as Map);
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
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('선택한 이미지 파일이 비어 있습니다.');
    }

    final upload = await requestUploadUrl(
      filename: filename,
      contentType: contentType,
    );
    final headers = Map<String, dynamic>.from(
      (upload['headers'] as Map?) ?? const {},
    );
    headers[Headers.contentTypeHeader] = contentType;

    // Flutter Web에서는 Content-Length 같은 제한 헤더를 직접 넣으면 브라우저가 막을 수 있습니다.
    await _uploadDio.put<void>(
      upload['upload_url'] as String,
      data: bytes,
      options: Options(headers: headers, responseType: ResponseType.plain),
    );

    return completeUpload(
      s3Key: upload['s3_key'] as String,
      imageUrl: upload['image_url'] as String?,
      originalFilename: filename,
      contentType: contentType,
    );
  }
}
