import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'models/complete_register_request.dart';
import 'models/complete_reset_password_request.dart';
import 'models/google_token_exchange_request.dart';
import 'models/login_request.dart';
import 'models/refresh_request.dart';
import 'models/send_email_request.dart';
import 'models/token_response.dart';
import 'models/verify_register_code_request.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<void> sendRegisterEmailCode(String email) async {
    await _dio.post(
      ApiConstants.registerSendCode,
      data: SendEmailRequest(email).toJson(),
    );
  }

  Future<void> verifyRegisterEmailCode(String email, String code) async {
    await _dio.post(
      ApiConstants.registerVerifyCode,
      data: VerifyRegisterCodeRequest(email: email, code: code).toJson(),
    );
  }

  Future<void> completeRegister(CompleteRegisterRequest request) async {
    await _dio.post(ApiConstants.registerComplete, data: request.toJson());
  }

  Future<void> sendResetPasswordEmailCode(String email) async {
    await _dio.post(
      ApiConstants.resetSendCode,
      data: SendEmailRequest(email).toJson(),
    );
  }

  Future<void> verifyResetPasswordEmailCode(String email, String code) async {
    await _dio.post(
      ApiConstants.resetVerifyCode,
      data: VerifyRegisterCodeRequest(email: email, code: code).toJson(),
    );
  }

  Future<void> completeResetPassword(
    CompleteResetPasswordRequest request,
  ) async {
    await _dio.post(ApiConstants.resetComplete, data: request.toJson());
  }

  Future<TokenResponse> login(LoginRequest request) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: request.toJson(),
    );
    return TokenResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TokenResponse> exchangeGoogleCode(
    GoogleTokenExchangeRequest request,
  ) async {
    final response = await _dio.post(
      ApiConstants.googleToken,
      data: request.toJson(),
    );
    return TokenResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TokenResponse> refresh(RefreshRequest request) async {
    final response = await _dio.post(
      ApiConstants.refresh,
      data: request.toJson(),
    );
    return TokenResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> logout(RefreshRequest request) async {
    await _dio.post(ApiConstants.logout, data: request.toJson());
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get(ApiConstants.me);
    return Map<String, dynamic>.from(response.data as Map);
  }
}

class LocalAuthApi {
  LocalAuthApi(this._dio);

  final Dio _dio;

  Future<TokenResponse> syncAuthenticatedUser({
    required String email,
    String? nickname,
    Object? externalUserId,
  }) async {
    final response = await _dio.post(
      ApiConstants.localAuthSync,
      data: {
        'email': email,
        'nickname': nickname,
        'external_user_id': externalUserId?.toString(),
      },
    );
    return TokenResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<TokenResponse> refresh(RefreshRequest request) async {
    final response = await _dio.post(
      ApiConstants.refresh,
      data: request.toJson(),
    );
    return TokenResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> logout(RefreshRequest request) async {
    await _dio.post(ApiConstants.logout, data: request.toJson());
  }
}
