import 'package:cloud_firestore/cloud_firestore.dart';

/// Skill levels a study roadmap can be tailored to.
const List<String> kSkillLevels = ['Beginner', 'Intermediate', 'Advanced'];

/// ---------------------------------------------------------------------------
/// STUDY ROADMAP (one AI-generated study plan) in Firestore:
///   users/{uid}/study_roadmaps/{roadmapId}
/// ---------------------------------------------------------------------------
class StudyRoadmap {
  final String id;
  final String subject;
  final DateTime examDate;

  /// Planned study hours per day.
  final int studyHours;

  /// One of [kSkillLevels] (Beginner / Intermediate / Advanced).
  final String skillLevel;

  /// The full AI-generated plan text.
  final String roadmap;

  final DateTime createdAt;

  const StudyRoadmap({
    required this.id,
    required this.subject,
    required this.examDate,
    required this.studyHours,
    required this.skillLevel,
    required this.roadmap,
    required this.createdAt,
  });

  /// Whole days from today until the exam (0 = today, negative = already past).
  int get daysUntilExam {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime exam = DateTime(examDate.year, examDate.month, examDate.day);
    return exam.difference(today).inDays;
  }

  factory StudyRoadmap.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return StudyRoadmap(
      id: doc.id,
      subject: (data['subject'] ?? '') as String,
      examDate: (data['examDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      studyHours: ((data['studyHours'] ?? 1) as num).toInt(),
      skillLevel: (data['skillLevel'] ?? 'Beginner') as String,
      roadmap: (data['roadmap'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'subject': subject,
    'examDate': Timestamp.fromDate(examDate),
    'studyHours': studyHours,
    'skillLevel': skillLevel,
    'roadmap': roadmap,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  StudyRoadmap copyWith({
    String? id,
    String? subject,
    DateTime? examDate,
    int? studyHours,
    String? skillLevel,
    String? roadmap,
    DateTime? createdAt,
  }) {
    return StudyRoadmap(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      examDate: examDate ?? this.examDate,
      studyHours: studyHours ?? this.studyHours,
      skillLevel: skillLevel ?? this.skillLevel,
      roadmap: roadmap ?? this.roadmap,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
