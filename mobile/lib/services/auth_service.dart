import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

/// نموذج بيانات المستخدم
class AuthUser {
  final String username;
  final String role;
  final String? universityId;
  final int? academicYear;
  final String? fullName;
  final String? email;

  const AuthUser({
    required this.username,
    required this.role,
    this.universityId,
    this.academicYear,
    this.fullName,
    this.email,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    username: json['username'] as String? ?? '',
    role: json['role'] as String? ?? 'student',
    universityId: json['university_id'] as String?,
    academicYear: json['academic_year'] is int
        ? json['academic_year'] as int
        : int.tryParse(json['academic_year']?.toString() ?? ''),
    fullName: json['full_name'] as String?,
    email: json['email'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'username': username,
    'role': role,
    'university_id': universityId,
    'academic_year': academicYear,
    'full_name': fullName,
    'email': email,
  };
}

/// نتيجة عملية المصادقة
class AuthResult {
  final bool success;
  final String? errorMessage;
  final AuthUser? user;

  const AuthResult.success(this.user) : success = true, errorMessage = null;

  const AuthResult.failure(this.errorMessage) : success = false, user = null;
}

/// خدمة المصادقة المركزية
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ─── Secure Storage ────────────────────────────────────
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const english = '0123456789';

    String result = input.trim();
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], english[i]);
      result = result.replaceAll(persian[i], english[i]);
    }
    return result;
  }

  // ─── LOGIN (by University ID & Password) ───────────────
  Future<AuthResult> login(
    String universityIdOrUsername,
    String password,
  ) async {
    try {
      final cleanIdentifier = normalizeDigits(universityIdOrUsername.trim());
      final response = await http
          .post(
            Uri.parse(AppConstants.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'university_id': cleanIdentifier,
              'username': cleanIdentifier,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> body = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        return AuthResult.failure(
          'استجابة غير متوقعة من الخادم (${response.statusCode})',
        );
      }

      if (response.statusCode == 200) {
        final accessToken = body['access'] as String?;
        final refreshToken = body['refresh'] as String?;

        if (accessToken == null || refreshToken == null) {
          return const AuthResult.failure('استجابة غير صالحة من الخادم');
        }

        // استخراج بيانات المستخدم من الـ JWT payload أو كائن user
        final payload = _decodeJwtPayload(accessToken);
        final userObj = body['user'] as Map<String, dynamic>?;

        final user = AuthUser(
          username:
              userObj?['username'] ??
              payload['username'] as String? ??
              cleanIdentifier,
          role: userObj?['role'] ?? payload['role'] as String? ?? 'student',
          universityId:
              userObj?['university_id'] ??
              payload['university_id'] as String? ??
              cleanIdentifier,
          academicYear: userObj?['academic_year'] is int
              ? userObj!['academic_year'] as int
              : (payload['academic_year'] is int
                    ? payload['academic_year'] as int
                    : 1),
          fullName: userObj?['full_name'] as String?,
          email: userObj?['email'] as String?,
        );

        // حفظ آمن للـ tokens وبيانات المستخدم
        await _saveUserSession(accessToken, refreshToken, user);

        return AuthResult.success(user);
      }

      // معالجة أخطاء الـ Validation و Django
      final detail =
          body['detail'] ??
          body['non_field_errors']?.first ??
          _extractFieldErrors(body) ??
          'بيانات الدخول غير صحيحة';
      return AuthResult.failure(detail.toString());
    } on Exception {
      return const AuthResult.failure(AppConstants.connectionErrorMessage);
    }
  }

  // ─── REGISTER (Sign Up) ────────────────────────────────
  Future<AuthResult> register({
    required String username,
    required String password,
    required String universityId,
    required int academicYear,
    String? fullName,
    String? email,
  }) async {
    try {
      final cleanId = normalizeDigits(universityId.trim());
      final cleanUsername = username.trim();

      final response = await http
          .post(
            Uri.parse(AppConstants.registerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': cleanUsername,
              'password': password,
              'university_id': cleanId,
              'academic_year': academicYear,
              if (fullName != null && fullName.isNotEmpty)
                'full_name': fullName.trim(),
              if (email != null && email.isNotEmpty) 'email': email.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> body = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        return AuthResult.failure(
          'استجابة غير متوقعة من الخادم (${response.statusCode})',
        );
      }

      if (response.statusCode == 201) {
        final accessToken = body['access'] as String?;
        final refreshToken = body['refresh'] as String?;
        final userObj = body['user'] as Map<String, dynamic>?;

        final user = AuthUser(
          username: userObj?['username'] ?? username,
          role: userObj?['role'] ?? 'student',
          universityId: userObj?['university_id'] ?? universityId,
          academicYear: userObj?['academic_year'] is int
              ? userObj!['academic_year'] as int
              : academicYear,
          fullName: userObj?['full_name'] as String? ?? fullName,
          email: userObj?['email'] as String? ?? email,
        );

        if (accessToken != null && refreshToken != null) {
          await _saveUserSession(accessToken, refreshToken, user);
        }

        return AuthResult.success(user);
      }

      final errorMsg =
          _extractFieldErrors(body) ??
          body['detail']?.toString() ??
          'فشل إنشاء الحساب';
      return AuthResult.failure(errorMsg);
    } on Exception {
      return const AuthResult.failure(AppConstants.connectionErrorMessage);
    }
  }

  // ─── REFRESH TOKEN ──────────────────────────────────────
  Future<String?> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
    if (refreshToken == null) return null;

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.refreshUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = body['access'] as String?;
        final newRefresh = body['refresh'] as String?;

        if (newAccess != null) {
          await _storage.write(
            key: AppConstants.keyAccessToken,
            value: newAccess,
          );
          if (newRefresh != null) {
            await _storage.write(
              key: AppConstants.keyRefreshToken,
              value: newRefresh,
            );
          }
          return newAccess;
        }
      }
    } catch (_) {}

    await logout();
    return null;
  }

  // ─── LOGOUT ─────────────────────────────────────────────
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ─── TOKEN & USER HELPERS ───────────────────────────────
  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.keyAccessToken);
  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.keyRefreshToken);

  Future<bool> isLoggedIn() async {
    final refresh = await _storage.read(key: AppConstants.keyRefreshToken);
    return refresh != null && refresh.isNotEmpty;
  }

  Future<AuthUser?> getStoredUser() async {
    final username = await _storage.read(key: AppConstants.keyUsername);
    final role = await _storage.read(key: AppConstants.keyRole);
    final universityId = await _storage.read(key: AppConstants.keyUniversityId);
    final yearStr = await _storage.read(key: AppConstants.keyAcademicYear);
    final fullName = await _storage.read(key: AppConstants.keyFullName);

    if (username == null) return null;
    return AuthUser(
      username: username,
      role: role ?? 'student',
      universityId: universityId,
      academicYear: int.tryParse(yearStr ?? ''),
      fullName: fullName,
    );
  }

  // ─── PRIVATE HELPERS ────────────────────────────────────
  Future<void> _saveUserSession(
    String accessToken,
    String refreshToken,
    AuthUser user,
  ) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyAccessToken, value: accessToken),
      _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken),
      _storage.write(key: AppConstants.keyUsername, value: user.username),
      _storage.write(key: AppConstants.keyRole, value: user.role),
      if (user.universityId != null)
        _storage.write(
          key: AppConstants.keyUniversityId,
          value: user.universityId!,
        ),
      if (user.academicYear != null)
        _storage.write(
          key: AppConstants.keyAcademicYear,
          value: user.academicYear.toString(),
        ),
      if (user.fullName != null)
        _storage.write(key: AppConstants.keyFullName, value: user.fullName!),
    ]);
  }

  String? _extractFieldErrors(Map<String, dynamic> body) {
    final List<String> errors = [];
    for (final entry in body.entries) {
      if (entry.value is List) {
        errors.add((entry.value as List).join(", "));
      } else if (entry.value is String) {
        errors.add(entry.value as String);
      }
    }
    return errors.isNotEmpty ? errors.first : null;
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
