import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class AuthUser {
  final String uid;
  final String username;
  final String role;
  final String? universityId;
  final int? academicYear;
  final String? fullName;
  final String? email;
  final String? profilePicture;
  final int xpPoints;
  final String studentStatus;

  const AuthUser({
    required this.uid,
    required this.username,
    required this.role,
    this.universityId,
    this.academicYear,
    this.fullName,
    this.email,
    this.profilePicture,
    this.xpPoints = 0,
    this.studentStatus = 'active',
  });

  factory AuthUser.fromFirestore(String uid, Map<String, dynamic> data) =>
      AuthUser(
        uid: uid,
        username: data['username'] as String? ?? '',
        role: data['role'] as String? ?? 'student',
        universityId: data['universityId'] as String?,
        academicYear: data['academicYear'] as int?,
        fullName: data['fullName'] as String?,
        email: data['email'] as String?,
        profilePicture: data['profilePicture'] as String?,
        xpPoints: data['xpPoints'] as int? ?? 0,
        studentStatus: data['studentStatus'] as String? ?? 'active',
      );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'role': role,
    'university_id': universityId,
    'academic_year': academicYear,
    'full_name': fullName,
    'email': email,
    'profile_picture': profilePicture,
    'xp_points': xpPoints,
  };
}

class AuthResult {
  final bool success;
  final String? errorMessage;
  final AuthUser? user;

  const AuthResult.success(this.user) : success = true, errorMessage = null;

  const AuthResult.failure(this.errorMessage) : success = false, user = null;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const requiredAcademicYear = 2;

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool isAllowedAcademicYear(int academicYear) =>
      academicYear == requiredAcademicYear;

  static String normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const english = '0123456789';
    var result = input.trim();
    for (var index = 0; index < 10; index++) {
      result = result.replaceAll(arabic[index], english[index]);
      result = result.replaceAll(persian[index], english[index]);
    }
    return result;
  }

  Future<AuthUser?> loadUser(firebase_auth.User? firebaseUser) async {
    if (firebaseUser == null) return null;
    final snapshot = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return AuthUser.fromFirestore(firebaseUser.uid, data);
  }

  static String _authEmailForStudentId(String studentId) =>
      'student-${studentId.toLowerCase()}@studychallenge-b4869.firebaseapp.com';

  static String _legacyAuthEmailForStudentId(String studentId) =>
      'student-${studentId.toLowerCase()}@login.study-challenge.invalid';

  static bool _isValidStudentId(String studentId) =>
      RegExp(r'^[A-Za-z0-9_-]{4,50}$').hasMatch(studentId);

  Future<AuthResult> login(
    String studentIdOrLegacyEmail,
    String password,
  ) async {
    try {
      final identifier = studentIdOrLegacyEmail.trim();
      if (!identifier.contains('@') &&
          !_isValidStudentId(normalizeDigits(identifier))) {
        return const AuthResult.failure('أدخل رقم طالب صالحًا.');
      }
      final normalizedIdentifier = normalizeDigits(identifier);
      final credential = identifier.contains('@')
          ? await _auth.signInWithEmailAndPassword(
              email: identifier.toLowerCase(),
              password: password,
            )
          : await _signInWithStudentId(normalizedIdentifier, password);
      final user = await loadUser(credential.user);
      if (user == null) {
        await _auth.signOut();
        return const AuthResult.failure(
          'ملف الحساب غير مكتمل. تواصل مع مسؤول التطبيق.',
        );
      }
      if (user.role == 'student' &&
          !isAllowedAcademicYear(user.academicYear ?? 0)) {
        await _auth.signOut();
        return const AuthResult.failure(
          'الدخول متاح حاليًا لطلاب الفرقة الثانية فقط.',
        );
      }
      if (user.role == 'student' && user.studentStatus == 'suspended') {
        await _auth.signOut();
        return const AuthResult.failure(
          'تم إيقاف هذا الحساب. تواصل مع المالك.',
        );
      }
      return AuthResult.success(user);
    } on firebase_auth.FirebaseAuthException catch (error) {
      debugPrint(
        'Firebase sign-in failed: ${error.code}; ${error.message ?? "No details"}',
      );
      return AuthResult.failure(_authErrorMessage(error.code, error.message));
    } on FirebaseException catch (error) {
      debugPrint(
        'Firestore profile load failed: plugin=${error.plugin}; '
        'code=${error.code}; message=${error.message ?? "No details"}',
      );
      return AuthResult.failure(_firestoreErrorMessage(error));
    } on Exception {
      return const AuthResult.failure('حدث خطأ غير متوقع أثناء تسجيل الدخول.');
    }
  }

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    required String universityId,
    required int academicYear,
    String? fullName,
  }) async {
    firebase_auth.User? firebaseUser;
    try {
      final normalizedUsername = username.trim().toLowerCase();
      final normalizedUniversityId = normalizeDigits(universityId);
      final normalizedContactEmail = email.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9_.-]{3,50}$').hasMatch(normalizedUsername)) {
        return const AuthResult.failure('اسم المستخدم غير صالح.');
      }
      if (!_isValidStudentId(normalizedUniversityId)) {
        return const AuthResult.failure(
          'رقم الطالب يجب أن يكون من 4 إلى 50 خانة.',
        );
      }
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(normalizedContactEmail)) {
        return const AuthResult.failure('صيغة البريد الإلكتروني غير صحيحة.');
      }
      if (password.length < 6) {
        return const AuthResult.failure(
          'كلمة المرور يجب أن تتكون من 6 أحرف على الأقل.',
        );
      }
      if (!isAllowedAcademicYear(academicYear)) {
        return const AuthResult.failure(
          'إنشاء الحساب متاح حاليًا لطلاب الفرقة الثانية فقط.',
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: _authEmailForStudentId(normalizedUniversityId),
        password: password,
      );
      firebaseUser = credential.user;
      if (firebaseUser == null) {
        return const AuthResult.failure('تعذر إنشاء مستخدم Firebase.');
      }
      final userRef = _firestore.collection('users').doc(firebaseUser.uid);
      final batch = _firestore.batch();
      batch.set(userRef, {
        'uid': firebaseUser.uid,
        'email': normalizedContactEmail,
        'authEmail': firebaseUser.email,
        'username': normalizedUsername,
        'role': 'student',
        'studentStatus': 'active',
        'universityId': normalizedUniversityId,
        'academicYear': academicYear,
        'fullName': fullName?.trim() ?? '',
        'profilePicture': '',
        'xpPoints': 0,
        'streak': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_firestore.collection('usernames').doc(normalizedUsername), {
        'uid': firebaseUser.uid,
      });
      batch.set(
        _firestore.collection('universityIds').doc(normalizedUniversityId),
        {'uid': firebaseUser.uid},
      );
      await batch.commit();
      return AuthResult.success(
        AuthUser.fromFirestore(firebaseUser.uid, {
          'uid': firebaseUser.uid,
          'username': normalizedUsername,
          'role': 'student',
          'universityId': normalizedUniversityId,
          'academicYear': academicYear,
          'fullName': fullName?.trim() ?? '',
          'email': normalizedContactEmail,
          'profilePicture': '',
          'xpPoints': 0,
          'studentStatus': 'active',
        }),
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      debugPrint(
        'Firebase registration failed: ${error.code}; '
        '${error.message ?? "No details"}',
      );
      await _cleanupFailedRegistration(firebaseUser);
      if (error.code == 'email-already-in-use') {
        return const AuthResult.failure('رقم الطالب مسجل بالفعل.');
      }
      return AuthResult.failure(_authErrorMessage(error.code, error.message));
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firebase registration write failed: '
        'plugin=${error.plugin}; code=${error.code}; '
        'message=${error.message ?? error.toString()}\n'
        'stackTrace:\n$stackTrace',
      );
      final cleanupSucceeded = await _cleanupFailedRegistration(firebaseUser);
      if (!cleanupSucceeded) {
        return const AuthResult.failure(
          'تعذر حفظ ملف الحساب، كما تعذر حذف حساب المصادقة تلقائيًا. '
          'لا تحاول التسجيل بالبريد نفسه مجددًا قبل التواصل مع الدعم.',
        );
      }
      if (error.code == 'permission-denied') {
        return const AuthResult.failure(
          'تعذر إنشاء الملف. تحقق من نشر قواعد Firestore، أو جرّب اسم مستخدم '
          'ورقم طالب مختلفين إذا كان أحدهما مسجلًا.',
        );
      }
      if (error.code == 'already-exists') {
        return const AuthResult.failure(
          'اسم المستخدم أو رقم الطالب مستخدم بالفعل.',
        );
      }
      return AuthResult.failure(
        error.message ?? 'تعذر حفظ الحساب في Firebase.',
      );
    } on StateError catch (error, stackTrace) {
      debugPrint(
        'Unexpected registration state error: $error\n'
        'stackTrace:\n$stackTrace',
      );
      final cleanupSucceeded = await _cleanupFailedRegistration(firebaseUser);
      return AuthResult.failure(
        cleanupSucceeded
            ? 'لم يتم إنشاء ملف الحساب. حاول مرة أخرى.'
            : 'تعذر إكمال التسجيل أو حذف حساب المصادقة تلقائيًا. '
                  'تواصل مع الدعم قبل إعادة المحاولة.',
      );
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'Unexpected registration exception: $error\n'
        'stackTrace:\n$stackTrace',
      );
      final cleanupSucceeded = await _cleanupFailedRegistration(firebaseUser);
      return AuthResult.failure(
        cleanupSucceeded
            ? 'حدث خطأ غير متوقع أثناء إنشاء الحساب.'
            : 'تعذر إكمال التسجيل أو حذف حساب المصادقة تلقائيًا. '
                  'تواصل مع الدعم قبل إعادة المحاولة.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Unexpected registration error: $error\n'
        'stackTrace:\n$stackTrace',
      );
      final cleanupSucceeded = await _cleanupFailedRegistration(firebaseUser);
      return AuthResult.failure(
        cleanupSucceeded
            ? 'حدث خطأ غير متوقع أثناء إنشاء الحساب.'
            : 'تعذر إكمال التسجيل أو حذف حساب المصادقة تلقائيًا. '
                  'تواصل مع الدعم قبل إعادة المحاولة.',
      );
    }
  }

  Future<firebase_auth.UserCredential> _signInWithStudentId(
    String studentId,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: _authEmailForStudentId(studentId),
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (!const [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
      ].contains(error.code)) {
        rethrow;
      }
      try {
        return await _auth.signInWithEmailAndPassword(
          email: _legacyAuthEmailForStudentId(studentId),
          password: password,
        );
      } on firebase_auth.FirebaseAuthException {
        throw error;
      }
    }
  }

  Future<bool> _cleanupFailedRegistration(
    firebase_auth.User? firebaseUser,
  ) async {
    if (firebaseUser == null) return true;
    try {
      await firebaseUser.delete();
      return true;
    } on firebase_auth.FirebaseAuthException catch (error) {
      debugPrint(
        'Failed to clean up Firebase registration: ${error.code}; '
        '${error.message ?? "No details"}',
      );
      try {
        await _auth.signOut();
      } on firebase_auth.FirebaseAuthException catch (signOutError) {
        debugPrint(
          'Failed to sign out after registration error: ${signOutError.code}',
        );
      }
      return false;
    } on FirebaseException catch (error) {
      debugPrint('Failed to clean up Firebase registration: ${error.code}');
      return false;
    } on Exception catch (error) {
      debugPrint('Failed to clean up Firebase registration: $error');
      return false;
    }
  }

  Future<void> logout() => _auth.signOut();

  Future<AuthUser?> getCurrentUser() async {
    final user = await loadUser(_auth.currentUser);
    if (user != null &&
        user.role == 'student' &&
        !isAllowedAcademicYear(user.academicYear ?? 0)) {
      await _auth.signOut();
      return null;
    }
    return user;
  }

  String _authErrorMessage(String code, [String? details]) {
    final normalizedDetails = details?.toUpperCase() ?? '';
    if (normalizedDetails.contains('RECAPTCHA') ||
        normalizedDetails.contains('PLAY INTEGRITY') ||
        normalizedDetails.contains('APP_NOT_VERIFIED')) {
      return 'تعذر التحقق من تطبيق Android لدى Firebase. أضف بصمتي SHA-1 و'
          'SHA-256 لشهادة التوقيع في إعدادات تطبيق Android داخل Firebase '
          'Console، ثم نزّل google-services.json من جديد.';
    }
    if (normalizedDetails.contains('CONFIGURATION_NOT_FOUND')) {
      return 'لم يتم إعداد Firebase Authentication لهذا المشروع. افتح '
          'Firebase Console للمشروع studychallenge-b4869 وفعّل Email/Password '
          'من Authentication → Sign-in method.';
    }
    if (normalizedDetails.contains('OPERATION_NOT_ALLOWED')) {
      return 'تسجيل البريد وكلمة المرور غير مفعّل. فعّل Email/Password من '
          'Firebase Console → Authentication → Sign-in method.';
    }
    return switch (code) {
      'invalid-email' => 'صيغة البريد الإلكتروني غير صحيحة.',
      'operation-not-allowed' =>
        'تسجيل البريد وكلمة المرور غير مفعّل في Firebase. فعّل Email/Password '
            'من Authentication ثم Sign-in method في Firebase Console.',
      'configuration-not-found' =>
        'لم يتم إعداد Firebase Authentication لهذا المشروع. افتح Firebase '
            'Console للمشروع studychallenge-b4869 ثم فعّل Email/Password من '
            'Authentication → Sign-in method.',
      'app-not-authorized' || 'invalid-api-key' =>
        'إعداد تطبيق Firebase غير صحيح لهذا المشروع. راجع google-services.json '
            'وتأكد من تطابق package name.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'رقم الطالب أو كلمة المرور غير صحيحة.',
      'email-already-in-use' => 'هذا البريد الإلكتروني مسجل مسبقًا.',
      'weak-password' => 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.',
      'too-many-requests' => 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.',
      'network-request-failed' => 'تحقق من اتصال الإنترنت ثم حاول مجددًا.',
      'unknown' =>
        'أعاد Firebase Authentication خطأً داخليًا. تأكد من تفعيل '
            'Email/Password، وتسجيل بصمتي SHA للتطبيق. '
            '${details?.trim().isNotEmpty == true ? "تفاصيل Firebase: $details" : "لا توجد تفاصيل إضافية من SDK."}',
      _ =>
        'تعذر إتمام المصادقة (رمز Firebase: $code). راجع إعدادات Firebase '
            'وحاول مرة أخرى.'
            '${details?.trim().isNotEmpty == true ? " التفاصيل: $details" : ""}',
    };
  }

  String _firestoreErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'تم التحقق من كلمة المرور، لكن قواعد Firestore منعت قراءة ملف الحساب. '
            'انشر قواعد Firestore للمشروع ثم حاول مجددًا.',
      'unavailable' || 'deadline-exceeded' =>
        'تعذر الوصول إلى Firestore. تحقق من الإنترنت، وتأكد من إنشاء قاعدة '
            'Firestore الافتراضية (default) في المشروع studychallenge-b4869؛ '
            'تفعيل Firestore API وحده لا ينشئ قاعدة البيانات.',
      'not-found' =>
        'قاعدة بيانات Firestore غير موجودة في مشروع Firebase المحدد. '
            'أنشئ قاعدة البيانات ثم حاول مجددًا.',
      'failed-precondition' =>
        'إعداد Firestore غير مكتمل. تحقق من تفعيل Firestore API وإعداد قاعدة '
            'البيانات في مشروع Firebase.',
      _ =>
        'تعذر تحميل ملف الحساب من Firestore '
            '(رمز الخطأ: ${error.code}). راجع إعدادات قاعدة البيانات وقواعدها.',
    };
  }
}
