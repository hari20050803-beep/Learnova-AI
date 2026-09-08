import 'package:cloud_firestore/cloud_firestore.dart';

/// Grade letter -> grade point. Used by the GPA Calculator dropdown.
const Map<String, double> kGradePoints = {
  'A+': 4.0,
  'A': 4.0,
  'A-': 3.7,
  'B+': 3.3,
  'B': 3.0,
  'B-': 2.7,
  'C+': 2.3,
  'C': 2.0,
  'C-': 1.7,
  'D': 1.0,
  'F': 0.0,
};

/// Grade letters in display order (for the dropdown).
const List<String> kGradeOrder = [
  'A+',
  'A',
  'A-',
  'B+',
  'B',
  'B-',
  'C+',
  'C',
  'C-',
  'D',
  'F',
];

/// A short, encouraging status message for a GPA value.
String gpaStatusMessage(double gpa) {
  if (gpa >= 3.7) return 'Outstanding — First Class standing!';
  if (gpa >= 3.3) return 'Excellent work — keep it up!';
  if (gpa >= 3.0) return 'Very good — a solid result.';
  if (gpa >= 2.7) return 'Good — a little more pushes you higher.';
  if (gpa >= 2.0) return 'Satisfactory — aim higher next time.';
  if (gpa >= 1.0) return 'Needs improvement — don\'t give up!';
  return 'At risk — consider getting extra support.';
}

/// ---------------------------------------------------------------------------
/// GPA SUBJECT (one module/course inside a GPA calculation)
/// Stored as a map inside the gpa_record document (not its own document).
/// ---------------------------------------------------------------------------
class GpaSubject {
  final String name;
  final double credit;
  final String grade;
  final double gradePoint;

  const GpaSubject({
    required this.name,
    required this.credit,
    required this.grade,
    required this.gradePoint,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'credit': credit,
    'grade': grade,
    'gradePoint': gradePoint,
  };

  factory GpaSubject.fromMap(Map<String, dynamic> map) => GpaSubject(
    name: (map['name'] ?? '') as String,
    credit: ((map['credit'] ?? 0) as num).toDouble(),
    grade: (map['grade'] ?? 'F') as String,
    gradePoint: ((map['gradePoint'] ?? 0) as num).toDouble(),
  );
}

/// ---------------------------------------------------------------------------
/// GPA RECORD (one saved semester) in Firestore:
///   users/{uid}/gpa_records/{recordId}
/// ---------------------------------------------------------------------------
class GpaRecord {
  final String id;
  final String semesterName;
  final List<GpaSubject> subjects;
  final double totalCredits;
  final double gpa;
  final DateTime createdAt;

  const GpaRecord({
    required this.id,
    required this.semesterName,
    required this.subjects,
    required this.totalCredits,
    required this.gpa,
    required this.createdAt,
  });

  factory GpaRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawSubjects = (data['subjects'] as List?) ?? const [];
    return GpaRecord(
      id: doc.id,
      semesterName: (data['semesterName'] ?? 'Semester') as String,
      subjects: rawSubjects
          .map((e) => GpaSubject.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalCredits: ((data['totalCredits'] ?? 0) as num).toDouble(),
      gpa: ((data['gpa'] ?? 0) as num).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'semesterName': semesterName,
    'subjects': subjects.map((s) => s.toMap()).toList(),
    'totalCredits': totalCredits,
    'gpa': gpa,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
