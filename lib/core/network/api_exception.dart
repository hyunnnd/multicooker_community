import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final data = error.response?.data;
    var message = '요청 처리 중 오류가 발생했습니다.';

    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail.first['msg']?.toString() ?? message;
      }
    } else if (error.message != null) {
      message = error.message!;
    }

    return ApiException(message, error.response?.statusCode);
  }

  @override
  String toString() => message;
}
