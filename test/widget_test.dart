// Automated checks for the parts of Learnova AI that can be exercised without
// a device, a network or a Firebase project.
//
// The screens themselves are verified by the manual test cases recorded in the
// test plan, because every one of them reads from Firebase Authentication or
// Cloud Firestore and neither can be reached from `flutter test`. What is
// covered here is the decision logic those screens depend upon: the password
// rules enforced at registration, the date format shown throughout the
// application, the grade bands of the GPA calculator, and the file handling
// introduced in the seventh session.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_student_dev/models/gpa_record.dart';
import 'package:ai_student_dev/models/study_material.dart';
import 'package:ai_student_dev/utils/format_date.dart';
import 'package:ai_student_dev/utils/password_strength.dart';

StudyMaterial material({
  String fileUrl = '',
  String storagePath = '',
  String fileType = 'image',
  String linkUrl = '',
}) {
  final DateTime now = DateTime(2026, 9, 7);
  return StudyMaterial(
    id: 'test',
    title: 'Newtons Laws of Motion',
    subject: 'Physics',
    category: 'Lecture Note',
    description: '',
    fileName: 'slide.png',
    fileUrl: fileUrl,
    fileType: fileType,
    linkUrl: linkUrl,
    storagePath: storagePath,
    summary: '',
    isFavorite: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Password rules', () {
    test('a short password fails on length first', () {
      final rules = PasswordRules.check('Ab1!');
      expect(rules.hasMinLength, isFalse);
      expect(rules.allMet, isFalse);
      expect(rules.firstProblem, contains('at least 8'));
    });

    test('a password missing a symbol is reported as such', () {
      final rules = PasswordRules.check('Learnova1');
      expect(rules.hasUppercase, isTrue);
      expect(rules.hasLowercase, isTrue);
      expect(rules.hasNumber, isTrue);
      expect(rules.hasSymbol, isFalse);
      expect(rules.firstProblem, contains('special symbol'));
    });

    test('eight acceptable characters rate as strong', () {
      final rules = PasswordRules.check('Learn1a!');
      expect(rules.allMet, isTrue);
      expect(rules.firstProblem, isNull);
      expect(rules.strength, PasswordStrength.strong);
    });

    test('twelve acceptable characters rate as very strong', () {
      expect(PasswordRules.check('Learnova#2026').strength,
          PasswordStrength.veryStrong);
    });

    test('an empty password is rated empty, not weak', () {
      expect(PasswordRules.check('').strength, PasswordStrength.empty);
    });

    test('three rules met is medium, two is weak', () {
      // upper + lower + length, no digit and no symbol
      expect(PasswordRules.check('Learnovaa').strength,
          PasswordStrength.medium);
      // lower only
      expect(PasswordRules.check('learn').strength, PasswordStrength.weak);
    });
  });

  group('Date format', () {
    test('pads the hour and the minute but not the day', () {
      expect(formatDateTime(DateTime(2026, 9, 7, 9, 5)), '7/9/2026 • 09:05');
    });

    test('renders midnight as 00:00 rather than 24:00', () {
      expect(formatDateTime(DateTime(2026, 1, 1)), '1/1/2026 • 00:00');
    });
  });

  group('GPA status message', () {
    test('reports first class standing at and above 3.7', () {
      expect(gpaStatusMessage(3.7), contains('First Class'));
      expect(gpaStatusMessage(4.0), contains('First Class'));
      expect(gpaStatusMessage(3.69), isNot(contains('First Class')));
    });

    test('each band returns a different message', () {
      final messages = <String>{
        gpaStatusMessage(3.8),
        gpaStatusMessage(3.4),
        gpaStatusMessage(3.1),
        gpaStatusMessage(2.8),
        gpaStatusMessage(2.2),
        gpaStatusMessage(1.5),
        gpaStatusMessage(0.5),
      };
      expect(messages.length, 7);
    });
  });

  group('Study material file handling', () {
    test('a file saved on the device is recognised as a device file', () {
      final m = material(storagePath: '/data/user/0/app/files/slide.png');
      expect(m.hasFile, isTrue);
      expect(m.isDeviceFile, isTrue);
      expect(m.canSummarize, isTrue);
      // Nothing to hand to the browser: it is opened by path.
      expect(m.openUrl, isEmpty);
    });

    test('an older cloud record is not treated as a device file', () {
      final m = material(
        fileUrl: 'https://example.com/slide.png',
        storagePath: 'users/uid/study_materials/slide.png',
      );
      expect(m.hasFile, isTrue);
      expect(m.isDeviceFile, isFalse);
      expect(m.openUrl, 'https://example.com/slide.png');
    });

    test('a link-only material has no file and opens its link', () {
      final m = material(fileType: 'link', linkUrl: 'https://example.com');
      expect(m.hasFile, isFalse);
      expect(m.canSummarize, isFalse);
      expect(m.openUrl, 'https://example.com');
    });

    test('AI can only read a PDF or an image', () {
      expect(material(storagePath: '/f/a.pdf', fileType: 'pdf').canSummarize,
          isTrue);
      expect(material(storagePath: '/f/a.doc', fileType: 'doc').canSummarize,
          isFalse);
    });
  });
}
