import 'package:cloud_firestore/cloud_firestore.dart';

/// One study reminder saved in Firestore (users/{uid}/study_reminders).
///
/// One model covers all four kinds:
///   'timetable'  - weekly class (dayOfWeek + start/end time)
///   'assignment' - has a due date and time
///   'exam'       - has an exam date and time
///   'study'      - study session (date + start/end, can repeat)
class StudyReminder {
  final String id;
  final String kind;
  final String title;
  final String subject;
  final String? lecturer; // timetable
  final String? location; // timetable
  final String? notes; // assignment / exam
  final int? dayOfWeek; // 1=Mon ... 7=Sun (timetable)
  final DateTime? startAt; // due date-time / session start / class start
  final DateTime? endAt; // class / session end
  final String repeat; // 'none' | 'daily' | 'weekly'

  /// Minutes before [startAt] to remind.
  /// Special case for assignment/exam: 0 means "same day at 8 AM".
  final int remindBefore;

  final bool isCompleted;

  /// Stable id used for the local notifications of this reminder.
  final int notifId;

  final DateTime createdAt;

  const StudyReminder({
    required this.id,
    required this.kind,
    required this.title,
    required this.subject,
    this.lecturer,
    this.location,
    this.notes,
    this.dayOfWeek,
    this.startAt,
    this.endAt,
    this.repeat = 'none',
    required this.remindBefore,
    this.isCompleted = false,
    required this.notifId,
    required this.createdAt,
  });

  factory StudyReminder.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return StudyReminder(
      id: doc.id,
      kind: (data['kind'] ?? 'study') as String,
      title: (data['title'] ?? '') as String,
      subject: (data['subject'] ?? '') as String,
      lecturer: data['lecturer'] as String?,
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      dayOfWeek: (data['dayOfWeek'] as num?)?.toInt(),
      startAt: (data['startAt'] as Timestamp?)?.toDate(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      repeat: (data['repeat'] ?? 'none') as String,
      remindBefore: ((data['remindBefore'] ?? 15) as num).toInt(),
      isCompleted: (data['isCompleted'] ?? false) as bool,
      notifId: ((data['notifId'] ?? 0) as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kind': kind,
      'title': title,
      'subject': subject,
      'lecturer': lecturer,
      'location': location,
      'notes': notes,
      'dayOfWeek': dayOfWeek,
      'startAt': startAt == null ? null : Timestamp.fromDate(startAt!),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'repeat': repeat,
      'remindBefore': remindBefore,
      'isCompleted': isCompleted,
      'notifId': notifId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  StudyReminder copyWith({String? id, bool? isCompleted}) {
    return StudyReminder(
      id: id ?? this.id,
      kind: kind,
      title: title,
      subject: subject,
      lecturer: lecturer,
      location: location,
      notes: notes,
      dayOfWeek: dayOfWeek,
      startAt: startAt,
      endAt: endAt,
      repeat: repeat,
      remindBefore: remindBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      notifId: notifId,
      createdAt: createdAt,
    );
  }

  /// When this reminder happens next (used for sorting + the Upcoming tab).
  /// Returns null when there is no date at all.
  DateTime? nextOccurrence() {
    final now = DateTime.now();
    final start = startAt;
    if (start == null) return null;

    if (repeat == 'weekly') {
      final int weekday = dayOfWeek ?? start.weekday;
      DateTime t = DateTime(
        now.year,
        now.month,
        now.day,
        start.hour,
        start.minute,
      );
      while (t.weekday != weekday || t.isBefore(now)) {
        t = t.add(const Duration(days: 1));
      }
      return t;
    }
    if (repeat == 'daily') {
      DateTime t = DateTime(
        now.year,
        now.month,
        now.day,
        start.hour,
        start.minute,
      );
      if (t.isBefore(now)) t = t.add(const Duration(days: 1));
      return t;
    }
    return start; // one-time (can be in the past, e.g. overdue assignment)
  }
}
