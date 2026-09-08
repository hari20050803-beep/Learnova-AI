import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/study_reminder.dart';

/// Thrown by [ReminderService] with a message safe to show to the user.
class ReminderException implements Exception {
  final String message;

  ReminderException(this.message);

  @override
  String toString() => message;
}

/// Small summary used by the main Dashboard screen.
class ReminderSummary {
  final StudyReminder? nextReminder;
  final DateTime? nextWhen;
  final int pendingAssignments;
  final int upcomingExams;

  const ReminderSummary({
    required this.nextReminder,
    required this.nextWhen,
    required this.pendingAssignments,
    required this.upcomingExams,
  });

  bool get hasAnything =>
      nextReminder != null || pendingAssignments > 0 || upcomingExams > 0;
}

/// ---------------------------------------------------------------------------
/// REMINDER SERVICE
/// All Firestore logic for study reminders, saved user-wise at:
///   users/{uid}/study_reminders/{reminderId}
/// ---------------------------------------------------------------------------
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reminders() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ReminderException('You are not logged in. Please login again.');
    }
    return _db.collection('users').doc(user.uid).collection('study_reminders');
  }

  /// Loads all reminders of the current user.
  Future<List<StudyReminder>> loadReminders() async {
    try {
      final snapshot = await _reminders()
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(StudyReminder.fromDoc).toList();
    } on FirebaseException catch (e) {
      throw ReminderException('Could not load reminders: ${e.message}');
    }
  }

  /// Saves a new reminder and returns it with its Firestore id.
  Future<StudyReminder> addReminder(StudyReminder reminder) async {
    try {
      final ref = await _reminders().add(reminder.toMap());
      return reminder.copyWith(id: ref.id);
    } on FirebaseException catch (e) {
      throw ReminderException('Could not save the reminder: ${e.message}');
    }
  }

  /// Updates an edited reminder.
  Future<void> updateReminder(StudyReminder reminder) async {
    try {
      await _reminders().doc(reminder.id).update(reminder.toMap());
    } on FirebaseException catch (e) {
      throw ReminderException('Could not update the reminder: ${e.message}');
    }
  }

  /// Marks a reminder as completed (or not completed again).
  Future<void> setCompleted(StudyReminder reminder, bool isCompleted) async {
    try {
      await _reminders().doc(reminder.id).update({'isCompleted': isCompleted});
    } on FirebaseException catch (e) {
      throw ReminderException('Could not update the reminder: ${e.message}');
    }
  }

  /// Deletes a reminder.
  Future<void> deleteReminder(StudyReminder reminder) async {
    try {
      await _reminders().doc(reminder.id).delete();
    } on FirebaseException catch (e) {
      throw ReminderException('Could not delete the reminder: ${e.message}');
    }
  }

  /// Summary for the main Dashboard: next upcoming reminder +
  /// pending assignments count + upcoming exams count.
  Future<ReminderSummary> loadSummary() async {
    final reminders = await loadReminders();
    final now = DateTime.now();

    StudyReminder? next;
    DateTime? nextWhen;
    int pendingAssignments = 0;
    int upcomingExams = 0;

    for (final reminder in reminders) {
      if (reminder.isCompleted) continue;

      if (reminder.kind == 'assignment') pendingAssignments++;
      if (reminder.kind == 'exam' &&
          (reminder.startAt?.isAfter(now) ?? false)) {
        upcomingExams++;
      }

      final DateTime? when = reminder.nextOccurrence();
      if (when != null && when.isAfter(now)) {
        if (nextWhen == null || when.isBefore(nextWhen)) {
          nextWhen = when;
          next = reminder;
        }
      }
    }

    return ReminderSummary(
      nextReminder: next,
      nextWhen: nextWhen,
      pendingAssignments: pendingAssignments,
      upcomingExams: upcomingExams,
    );
  }
}
