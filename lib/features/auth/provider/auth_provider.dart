import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/complete_register_request.dart';
import '../data/models/complete_reset_password_request.dart';
import '../data/models/token_response.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  bool isLoading = false;
  bool isAuthenticated = false;
  bool localApiReady = false;
  String? errorMessage;
  String? localApiError;
  TokenResponse? token;
  String? currentEmail;
  String? currentNickname;
  int currentAvatarColor = 0xFFFF8C42;

  Future<void> checkAuthStatus() async {
    isLoading = true;
    errorMessage = null;
    localApiError = null;
    localApiReady = false;
    notifyListeners();

    final hasToken = await _repository.hasAccessToken();
    if (!hasToken) {
      isAuthenticated = false;
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final profile = await _repository.restoreCompanyProfile();
      _applyProfile(profile);
      isAuthenticated = true;
      await _restoreLocalApi(profile);
    } catch (error) {
      final unauthorized = error is ApiException && error.statusCode == 401;
      if (unauthorized) {
        // A rejected stored token is not a valid login session. Clearing it
        // prevents an old email from remaining visible while all APIs return 401.
        await _repository.clearStoredSession();
        isAuthenticated = false;
        localApiReady = false;
        currentEmail = null;
        currentNickname = null;
        currentAvatarColor = 0xFFFF8C42;
        errorMessage = error.toString();
      } else {
        // A temporary company-server/network failure must not erase a valid
        // local session. Use the token payload profile and keep retrying the
        // personal API session instead of forcing a logout.
        try {
          final fallbackProfile = await _repository.me();
          _applyProfile(fallbackProfile);
          isAuthenticated = true;
          await _restoreLocalApi(fallbackProfile);
        } catch (_) {
          isAuthenticated = true;
          localApiReady = false;
          localApiError = error.toString();
        }
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> retryLocalApiSession() async {
    if (!isAuthenticated) return false;
    localApiError = null;
    notifyListeners();
    try {
      final profile = await _repository.me();
      _applyProfile(profile);
      await _repository.ensureLocalApiSession(companyProfile: profile);
      localApiReady = true;
      return true;
    } catch (error) {
      localApiReady = false;
      localApiError = error.toString();
      return false;
    } finally {
      notifyListeners();
    }
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
      final profile = await _repository.restoreCompanyProfile();
      _applyProfile(profile);
      isAuthenticated = true;
      await _restoreLocalApi(profile);
    });
  }

  Future<bool> loginWithGoogleCode(String code) async {
    return _run(() async {
      token = await _repository.loginWithGoogleCode(code);
      final profile = await _repository.restoreCompanyProfile();
      _applyProfile(profile);
      isAuthenticated = true;
      await _restoreLocalApi(profile);
    });
  }

  Future<bool> refreshToken() async {
    return _run(() async {
      token = await _repository.refreshToken();
      isAuthenticated = token != null;
      if (isAuthenticated) {
        final profile = await _repository.restoreCompanyProfile();
        _applyProfile(profile);
        await _restoreLocalApi(profile);
      }
    });
  }

  Future<void> logout() async {
    await _run(() async {
      await _repository.logout();
      token = null;
      isAuthenticated = false;
      localApiReady = false;
      localApiError = null;
      currentEmail = null;
      currentNickname = null;
      currentAvatarColor = 0xFFFF8C42;
    });
  }

  Future<void> _restoreLocalApi(Map<String, dynamic> profile) async {
    try {
      await _repository.ensureLocalApiSession(companyProfile: profile);
      localApiReady = true;
      localApiError = null;
    } catch (error) {
      // Company login remains valid. The API interceptor and retry button can
      // rebuild the local token when the personal server becomes available.
      localApiReady = false;
      localApiError = error.toString();
    }
  }

  Future<void> _loadMe({bool silent = false}) async {
    try {
      final data = await _repository.me();
      _applyProfile(data);
    } catch (error) {
      if (!silent) errorMessage = error.toString();
    }
  }

  void _applyProfile(Map<String, dynamic> data) {
    currentEmail = data['email'] as String?;
    currentNickname = data['nickname'] as String?;
    final avatar = data['avatar_color'];
    if (avatar is int) currentAvatarColor = avatar;
    if (avatar is num) currentAvatarColor = avatar.toInt();
  }

  void setLocalNickname(String nickname) {
    final value = nickname.trim();
    if (value.isEmpty) return;
    currentNickname = value;
    notifyListeners();
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
