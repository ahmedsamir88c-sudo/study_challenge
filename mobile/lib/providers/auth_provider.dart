import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

/// حالات المصادقة الممكنة
enum AuthStatus {
  /// جاري التحقق من الجلسة المحفوظة (عند بدء التطبيق)
  checking,
  /// مسجّل دخول وجلسة صالحة
  authenticated,
  /// غير مسجّل أو انتهت الجلسة
  unauthenticated,
}

/// مزود حالة المصادقة
class AuthProvider extends ChangeNotifier {
  final _auth = AuthService.instance;

  AuthStatus _status = AuthStatus.checking;
  AuthUser?  _user;
  String?    _errorMessage;
  bool       _isLoading = false;

  // ─── Getters ───────────────────────────────────────────
  AuthStatus get status       => _status;
  AuthUser?  get user         => _user;
  String?    get errorMessage => _errorMessage;
  bool       get isLoading    => _isLoading;
  bool       get isAuth       => _status == AuthStatus.authenticated;

  // ─── INIT: التحقق من الجلسة عند بدء التطبيق ──────────
  AuthProvider() {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    _status = AuthStatus.checking;
    notifyListeners();

    final loggedIn = await _auth.isLoggedIn();
    if (loggedIn) {
      final newToken = await _auth.refreshAccessToken();
      if (newToken != null) {
        _user   = await _auth.getStoredUser();
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // ─── LOGIN (by University ID & Password) ───────────────
  Future<bool> login(String universityIdOrUsername, String password) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _auth.login(universityIdOrUsername, password);

    _isLoading = false;

    if (result.success) {
      _user   = result.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } else {
      _errorMessage = result.errorMessage;
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
    return result.success;
  }

  // ─── REGISTER (Sign Up) ────────────────────────────────
  Future<bool> register({
    required String username,
    required String password,
    required String universityId,
    required int academicYear,
    String? fullName,
    String? email,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _auth.register(
      username: username,
      password: password,
      universityId: universityId,
      academicYear: academicYear,
      fullName: fullName,
      email: email,
    );

    _isLoading = false;

    if (result.success) {
      _user   = result.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } else {
      _errorMessage = result.errorMessage;
    }

    notifyListeners();
    return result.success;
  }

  // ─── LOGOUT ────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.logout();
    _user         = null;
    _errorMessage = null;
    _status       = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── عند 401 من ApiClient (جلسة منتهية) ───────────────
  void forceLogout() {
    _user         = null;
    _errorMessage = 'انتهت جلستك. الرجاء تسجيل الدخول مجدداً.';
    _status       = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
