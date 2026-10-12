import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<ApiResponse> get(
    String url, {
    Duration timeout = const Duration(seconds: 30),
  }) => _request('GET', url, timeout: timeout);

  Future<ApiResponse> post(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) => _request('POST', url, body: body, timeout: timeout);

  Future<ApiResponse> patch(String url, Map<String, dynamic> body) =>
      _request('PATCH', url, body: body);

  Future<ApiResponse> delete(String url) => _request('DELETE', url);

  Future<ApiResponse> postFiles(
    String url, {
    required Map<String, String> fields,
    required List<ApiFile> files,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (files.isEmpty || files.length > 20) {
      return ApiResponse.failure('اختر من ملف واحد إلى 20 ملفًا.');
    }
    if (files.any((file) => file.bytes.length > 30 * 1024 * 1024)) {
      return ApiResponse.failure('حجم الملف يتجاوز الحد المسموح به (30 ميجابايت).');
    }
    try {
      final uid = _requireUid();
      final uploaded = <Map<String, dynamic>>[];
      for (final file in files) {
        final safeName = file.filename.replaceAll(
          RegExp(r'[^A-Za-z0-9._-]'),
          '_',
        );
        final path =
            'studyMaterials/$uid/${DateTime.now().microsecondsSinceEpoch}_$safeName';
        final ref = _storage.ref(path);
        await ref.putData(
          file.bytes,
          SettableMetadata(contentType: _contentType(file.filename)),
        );
        uploaded.add({
          'path': path,
          'filename': file.filename,
          'size': file.bytes.length,
          'contentType': _contentType(file.filename),
        });
      }
      return await _request(
        'POST',
        url,
        body: {...fields, 'files': uploaded},
        timeout: timeout,
      );
    } on FirebaseException catch (error) {
      return ApiResponse.failure(
        error.message ?? 'تعذر رفع الملف إلى Firebase Storage.',
        isAuthError: error.code == 'unauthenticated',
      );
    }
  }

  Future<ApiResponse> patchFile(
    String url, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final uid = _requireUid();
      final path =
          'profilePictures/$uid/${DateTime.now().microsecondsSinceEpoch}_$filename';
      await _storage
          .ref(path)
          .putData(
            bytes,
            SettableMetadata(contentType: _contentType(filename)),
          );
      return await patch(url, {fieldName: path});
    } on FirebaseException catch (error) {
      return ApiResponse.failure(
        error.message ?? 'تعذر رفع الصورة إلى Firebase Storage.',
        isAuthError: error.code == 'unauthenticated',
      );
    }
  }

  Future<ApiFileResponse> getFile(String url) async {
    try {
      final metadata = await _request('GET', url);
      if (!metadata.isSuccess || metadata.body is! Map) {
        return ApiFileResponse(
          statusCode: metadata.statusCode,
          bytes: null,
          isSuccess: false,
          isAuthError: metadata.isAuthError,
          errorMessage: metadata.errorMessage,
        );
      }
      final path = (metadata.body as Map)['storage_path']?.toString();
      if (path == null || path.isEmpty) {
        return const ApiFileResponse(
          statusCode: 404,
          bytes: null,
          isSuccess: false,
          isAuthError: false,
          errorMessage: 'لم يتم العثور على الملف في Firebase Storage.',
        );
      }
      final bytes = await _storage.ref(path).getData(50 * 1024 * 1024);
      if (bytes == null) {
        return const ApiFileResponse(
          statusCode: 404,
          bytes: null,
          isSuccess: false,
          isAuthError: false,
          errorMessage: 'تعذر تنزيل الملف.',
        );
      }
      return ApiFileResponse(
        statusCode: 200,
        bytes: bytes,
        isSuccess: true,
        isAuthError: false,
        errorMessage: '',
      );
    } on FirebaseException catch (error) {
      return ApiFileResponse(
        statusCode: 500,
        bytes: null,
        isSuccess: false,
        isAuthError: error.code == 'unauthenticated',
        errorMessage: error.message ?? 'تعذر تنزيل الملف.',
      );
    }
  }

  Future<ApiResponse> _request(
    String method,
    String url, {
    Map<String, dynamic> body = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      _requireUid();
      final uri = Uri.parse(url);
      final rawData = await _callFeature(
        method,
        uri.path,
        uri.queryParameters,
        body,
        timeout,
      );
      final data = rawData.containsKey('status_code')
          ? rawData
          : {'body': rawData, 'status_code': 200};
      final statusCode = data['status_code'] is int
          ? data['status_code'] as int
          : 200;
      final responseBody = data['body'] ?? <String, dynamic>{};
      return ApiResponse(
        statusCode: statusCode,
        body: responseBody,
        isSuccess: statusCode >= 200 && statusCode < 300,
        isAuthError: false,
      );
    } on FirebaseFunctionsException catch (error) {
      return ApiResponse.failure(
        error.message ?? AppConstants.unexpectedErrorMessage,
        isAuthError: error.code == 'unauthenticated',
      );
    } on FirebaseAuthException {
      return ApiResponse.failure(
        'انتهت جلسة Firebase. سجّل الدخول مرة أخرى.',
        isAuthError: true,
      );
    } on FirebaseException catch (error) {
      return ApiResponse.failure(
        error.message ?? AppConstants.connectionErrorMessage,
        isAuthError: error.code == 'unauthenticated',
      );
    } on Exception {
      return ApiResponse.failure(AppConstants.connectionErrorMessage);
    }
  }

  Future<Map<String, dynamic>> _callFeature(
      String method,
      String path,
      Map<String, String> query,
      Map<String, dynamic> body,
      Duration timeout,
    ) async {
      if (method == 'GET' && path == '/api/study/daily-challenge/') {
        return (await _functions
                .httpsCallable(
                  'getDailyChallenge',
                  options: HttpsCallableOptions(timeout: timeout),
                )
                .call<Map<String, dynamic>>())
            .data;
      }
      if (method == 'POST' && path == '/api/auth/quizzes/setup/') {
        final subjectId = await _findSubjectId(
          body['subject']?.toString() ?? '',
        );
        final lecture = await _findLecture(
          subjectId,
          int.tryParse(body['lecture']?.toString() ?? ''),
        );
        return (await _functions
                .httpsCallable(
                  'startQuiz',
                  options: HttpsCallableOptions(timeout: timeout),
                )
                .call<Map<String, dynamic>>({
                  'subjectId': subjectId,
                  'lectureId': lecture.id,
                  'count': body['count'],
                  'difficulty': body['difficulty'],
                  'dailyChallenge': body['daily_challenge'] == true,
                }))
            .data;
      }
      if (method == 'POST' && path == '/api/auth/quizzes/submit/') {
        return (await _functions
                .httpsCallable(
                  'submitQuiz',
                  options: HttpsCallableOptions(timeout: timeout),
                )
                .call<Map<String, dynamic>>({
                  'quiz_id': body['quiz_id'],
                  'answers': body['answers'],
                }))
            .data;
      }
      if (path == '/api/auth/ai/chat/' || path == '/api/auth/ai/summarize/') {
        final subjectId = await _findSubjectId(
          body['subject']?.toString() ?? '',
        );
        final lectureNumber = int.tryParse(body['lecture']?.toString() ?? '');
        final lecture = lectureNumber == null
            ? null
            : await _findLecture(subjectId, lectureNumber);
        return (await _functions
                .httpsCallable(
                  'academicAssistant',
                  options: HttpsCallableOptions(timeout: timeout),
                )
                .call<Map<String, dynamic>>({
                  'subjectId': subjectId,
                  if (lecture != null) 'lectureId': lecture.id,
                  if (path.endsWith('/chat/')) 'message': body['message'],
                  if (path.endsWith('/summarize/'))
                    'summaryType': body['summary_type'],
                }))
            .data;
      }
      return (await _functions
              .httpsCallable(
                'firebaseApi',
                options: HttpsCallableOptions(timeout: timeout),
              )
              .call<Map<String, dynamic>>({
                'method': method,
                'path': path,
                'query': query,
                'body': body,
              }))
          .data;
    }

  Future<String> _findSubjectId(String name) async {
      final profile = await _firestore
          .collection('users')
          .doc(_requireUid())
          .get();
      final year = profile.data()?['academicYear'];
      final subjects = await _firestore
          .collection('subjects')
          .where('yearNumber', isEqualTo: year)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (subjects.docs.isEmpty) {
        throw FirebaseFunctionsException(
          code: 'not-found',
          message: 'المادة غير متاحة لهذه الفرقة.',
        );
      }
      return subjects.docs.first.id;
    }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _findLecture(
      String subjectId,
      int? lectureNumber,
    ) async {
      if (lectureNumber == null) {
        throw FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'رقم المحاضرة غير صالح.',
        );
      }
      final lectures = await _firestore
          .collection('lectures')
          .where('subjectId', isEqualTo: subjectId)
          .where('lectureNumber', isEqualTo: lectureNumber)
          .limit(1)
          .get();
      if (lectures.docs.isEmpty) {
        throw FirebaseFunctionsException(
          code: 'not-found',
          message: 'المحاضرة غير موجودة.',
        );
      }
      return lectures.docs.first;
  }

  String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw FirebaseAuthException(code: 'unauthenticated');
    return uid;
  }

  String _contentType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }
}

class ApiResponse {
  final int statusCode;
  final dynamic body;
  final bool isSuccess;
  final bool isAuthError;

  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.isSuccess,
    required this.isAuthError,
  });

  factory ApiResponse.failure(String message, {bool isAuthError = false}) =>
      ApiResponse(
        statusCode: isAuthError ? 401 : 500,
        body: {'detail': message},
        isSuccess: false,
        isAuthError: isAuthError,
      );

  String get errorMessage {
    if (body is Map) {
      final value =
          (body as Map)['detail'] ??
          (body as Map)['message'] ??
          'خطأ غير معروف';
      if (value is List) return value.map((item) => item.toString()).join('\n');
      return value.toString();
    }
    return 'خطأ غير معروف';
  }
}

class ApiFile {
  const ApiFile({
    required this.fieldName,
    required this.filename,
    required this.bytes,
  });

  final String fieldName;
  final String filename;
  final Uint8List bytes;
}

class ApiFileResponse {
  const ApiFileResponse({
    required this.statusCode,
    required this.bytes,
    required this.isSuccess,
    required this.isAuthError,
    required this.errorMessage,
  });

  final int statusCode;
  final Uint8List? bytes;
  final bool isSuccess;
  final bool isAuthError;
  final String errorMessage;
}
