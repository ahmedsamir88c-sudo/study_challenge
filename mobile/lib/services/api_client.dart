import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'auth_service.dart';

/// HTTP Client ذكي — يُضيف Authorization header تلقائياً
/// ويُجدّد الـ access token عند استلام 401
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final _auth = AuthService.instance;

  // ─── GET ────────────────────────────────────────────────
  Future<ApiResponse> get(String url) => _request(() async {
    final token = await _auth.getAccessToken();
    return http.get(Uri.parse(url), headers: _headers(token));
  });

  // ─── POST ───────────────────────────────────────────────
  Future<ApiResponse> post(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) => _request(() async {
    final token = await _auth.getAccessToken();
    return http.post(
      Uri.parse(url),
      headers: _headers(token),
      body: jsonEncode(body),
    );
  }, timeout: timeout);

  // ─── PATCH ──────────────────────────────────────────────
  Future<ApiResponse> patch(String url, Map<String, dynamic> body) =>
      _request(() async {
        final token = await _auth.getAccessToken();
        return http.patch(
          Uri.parse(url),
          headers: _headers(token),
          body: jsonEncode(body),
        );
      });

  Future<ApiResponse> patchFile(
    String url, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
  }) => _request(() async {
    final token = await _auth.getAccessToken();
    final request = http.MultipartRequest('PATCH', Uri.parse(url));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
    );
    final streamedResponse = await request.send();
    return http.Response.fromStream(streamedResponse);
  });

  // ─── CORE LOGIC: Auto Refresh on 401 ─────────────────────
  Future<ApiResponse> _request(
    Future<http.Response> Function() makeRequest, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      var response = await makeRequest().timeout(timeout);

      // إذا جاء 401 → نُجدّد الـ token ونُعيد المحاولة مرة واحدة
      if (response.statusCode == 401) {
        final newToken = await _auth.refreshAccessToken();
        if (newToken != null) {
          response = await makeRequest().timeout(timeout);
        } else {
          // فشل الـ refresh → جلسة منتهية
          return ApiResponse(
            statusCode: 401,
            body: {},
            isSuccess: false,
            isAuthError: true,
          );
        }
      }

      final decoded = _tryDecode(response.body);
      return ApiResponse(
        statusCode: response.statusCode,
        body: decoded,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
        isAuthError: response.statusCode == 401,
      );
    } on Exception {
      return ApiResponse(
        statusCode: 0,
        body: {'detail': AppConstants.connectionErrorMessage},
        isSuccess: false,
        isAuthError: false,
      );
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────
  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'raw': body};
    }
  }
}

/// استجابة موحدة من جميع طلبات الـ API
class ApiResponse {
  final int statusCode;
  final dynamic body;
  final bool isSuccess;

  /// true = الـ token منتهي ويجب إعادة المستخدم لـ Login
  final bool isAuthError;

  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.isSuccess,
    required this.isAuthError,
  });

  /// استخراج رسالة الخطأ بشكل ذكي
  String get errorMessage {
    if (body is Map) {
      final b = body as Map;
      return (b['detail'] ??
              b['message'] ??
              b['non_field_errors']?.toString() ??
              'خطأ غير معروف')
          .toString();
    }
    return 'خطأ غير معروف';
  }
}
