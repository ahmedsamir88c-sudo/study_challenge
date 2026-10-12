import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/services/auth_service.dart';

void main() {
  group('student academic year policy', () {
    test('allows only the second year', () {
      expect(AuthService.isAllowedAcademicYear(2), isTrue);
      expect(AuthService.isAllowedAcademicYear(1), isFalse);
      expect(AuthService.isAllowedAcademicYear(3), isFalse);
      expect(AuthService.isAllowedAcademicYear(4), isFalse);
    });
  });

  test('every configured subject has sixteen lectures', () {
    expect(AppConstants.subjectLectureCounts.values, everyElement(16));
  });
}
