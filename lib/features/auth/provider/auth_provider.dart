import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/models/complete_register_request.dart';
import '../data/models/complete_reset_password_request.dart';
import '../data/models/token_response.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  bool isLoading = false;
  bool isAuthenticated = false;
  String? errorMessage;
  TokenResponse? token;
  String? currentEmail;
  String? currentNickname;
  int currentAvatarColor = 0xFFFF8C42;

  Future<void> checkAuthStatus() async {
    isLoading = true;
    notifyListeners();
    isAuthenticated = await _repository.hasAccessToken();
    if (isAuthenticated) {
      await _loadMe(silent: true);
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> sendRegisterEmailCode(String email) =>
      _run(() => _repository.sendRegisterEmailCode(email));

  Future<bool> verifyRegisterEmailCode(String email, String code) =>
      _run(() => _repository.verifyRegisterEmailCode(email, code));

  Future<bool> completeRegister(CompleteRegisterRequest request) =>
      _run(() => _repository.completeRegister(request));

  Future<bool> sendResetPasswordEmailCode(String email) =>
      _run(() => _repository.sendResetPasswordEmailCode(email));

  Future<bool> verifyResetPasswordEmailCode(String email, String code) =>
      _run(() => _repository.verifyResetPasswordEmailCode(email, code));

  Future<bool> completeResetPassword(CompleteResetPasswordRequest request) =>
      _run(() => _repository.completeResetPassword(request));

  Future<bool> login(String email, String password) async {
    return _run(() async {
      token = await _repository.login(email, password);
      isAuthenticated = true;
      await _loadMe(silent: true);
    });
  }

  Future<bool> refreshToken() async {
    return _run(() async {
      token = await _repository.refreshToken();
      isAuthenticated = token != null;
      if (isAuthenticated) await _loadMe(silent: true);
    });
  }

  Future<void> logout() async {
    await _run(() async {
      await _repository.logout();
      token = null;
      isAuthenticated = false;
      currentEmail = null;
      currentNickname = null;
      currentAvatarColor = 0xFFFF8C42;
    });
  }

  Future<void> _loadMe({bool silent = false}) async {
    try {
      final data = await _repository.me();
      currentEmail = data['email'] as String?;
      currentNickname = data['nickname'] as String?;
      final avatar = data['avatar_color'];
      if (avatar is int) currentAvatarColor = avatar;
      if (avatar is num) currentAvatarColor = avatar.toInt();
    } catch (error) {
      if (!silent) errorMessage = error.toString();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
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
