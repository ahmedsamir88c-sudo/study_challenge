import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

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
  AuthUser? _user;
  String? _errorMessage;
  bool _isLoading = false;

  // ─── Getters ───────────────────────────────────────────
  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuth => _status == AuthStatus.authenticated;

  // ─── INIT: التحقق من الجلسة عند بدء التطبيق ──────────
  AuthProvider() {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    _status = AuthStatus.checking;
    notifyListeners();

    try {
      _user = await _auth.getCurrentUser();
      _status = _user == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } on firebase_auth.FirebaseAuthException {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'تعذر التحقق من جلسة Firebase.';
    } on Exception {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'تعذر تحميل بيانات الحساب من Firebase.';
    }

    notifyListeners();
  }

  // ─── LOGIN (by student ID and password) ────────────────
  Future<bool> login(String studentId, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _auth.login(studentId, password);
      if (result.success) {
        _user = result.user;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } else {
        _errorMessage = result.errorMessage;
        _status = AuthStatus.unauthenticated;
      }
      return result.success;
    } on Exception catch (error) {
      debugPrint('Unexpected login failure: $error');
      _errorMessage = 'تعذر تسجيل الدخول. تحقق من الاتصال وإعدادات Firebase.';
      _status = AuthStatus.unauthenticated;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── REGISTER (Sign Up) ────────────────────────────────
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String universityId,
    required int academicYear,
    String? fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _auth.register(
        username: username,
        email: email,
        password: password,
        universityId: universityId,
        academicYear: academicYear,
        fullName: fullName,
      );
      if (result.success) {
        _user = result.user;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } else {
        _errorMessage = result.errorMessage;
      }
      return result.success;
    } on Exception catch (error) {
      debugPrint('Unexpected registration failure: $error');
      _errorMessage =
          'تعذر إنشاء الحساب. تحقق من إعدادات Firebase وحاول مرة أخرى.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── LOGOUT ────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── عند 401 من ApiClient (جلسة منتهية) ───────────────
  void forceLogout() {
    unawaited(_auth.logout());
    _user = null;
    _errorMessage = 'انتهت جلستك. الرجاء تسجيل الدخول مجدداً.';
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
