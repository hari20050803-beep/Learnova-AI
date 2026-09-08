import 'package:flutter/material.dart';

import '../models/learning_stats.dart';
import '../models/quiz_result.dart';
import 'flashcard_service.dart';
import 'gpa_service.dart';
import 'history_service.dart';
import 'material_service.dart';
import 'note_service.dart';
import 'reminder_service.dart';

/// ---------------------------------------------------------------------------
/// LEARNING STATS SERVICE
/// Builds the Home screen numbers from data the app ALREADY stores. It only
/// reads — nothing new is written to Firestore, and no existing service is
/// changed. Every source is wrapped so one failure never blanks the screen.
/// ---------------------------------------------------------------------------
class LearningStatsService {
  LearningStatsService._();

  static final LearningStatsService instance = LearningStatsService._();

  /// XP awarded per completed item.
  static const int _xpQuiz = 50;
  static const int _xpSummary = 15;
  static const int _xpNote = 10;
  static const int _xpChat = 10;
  static const int _xpMaterial = 10;
  static const int _xpFlashcard = 5;

  /// Loads everything the Home screen shows.
  Future<LearningStats> load() async {
    // ---- Gather the raw data (each source fails soft) ----
    List<QuizResult> quizzes = const [];
    try {
      quizzes = await HistoryService.instance.loadQuizHistory();
    } catch (_) {}

    int chatCount = 0;
    List<DateTime> chatDates = const [];
    try {
      final sessions = await HistoryService.instance.loadChatSessions();
      chatCount = sessions.length;
      chatDates = sessions.map((s) => s.updatedAt).toList();
    } catch (_) {}

    int summaryCount = 0;
    List<DateTime> summaryDates = const [];
    try {
      final summaries = await HistoryService.instance.loadSummaries();
      summaryCount = summaries.length;
      summaryDates = summaries.map((s) => s.createdAt).toList();
    } catch (_) {}

    int noteCount = 0;
    List<DateTime> noteDates = const [];
    try {
      final notes = await NoteService.instance.loadNotes();
      noteCount = notes.length;
      noteDates = notes.map((n) => n.createdAt).toList();
    } catch (_) {}

    int materialCount = 0;
    try {
      materialCount = (await MaterialService.instance.loadSummary()).total;
    } catch (_) {}

    int flashcardCount = 0;
    try {
      flashcardCount =
          (await FlashcardService.instance.loadFlashcards()).length;
    } catch (_) {}

    double? gpa;
    try {
      gpa = (await GpaService.instance.loadLatest())?.gpa;
    } catch (_) {}

    int pendingAssignments = 0;
    int upcomingExams = 0;
    int completedRemindersToday = 0;
    try {
      final summary = await ReminderService.instance.loadSummary();
      pendingAssignments = summary.pendingAssignments;
      upcomingExams = summary.upcomingExams;
    } catch (_) {}
    try {
      final reminders = await ReminderService.instance.loadReminders();
      // startAt is the due / session time and may be null on a timetable
      // entry, so fall back to when the reminder was created.
      completedRemindersToday = reminders
          .where((r) => r.isCompleted && _isToday(r.startAt ?? r.createdAt))
          .length;
    } catch (_) {}

    // ---- Today's progress ----
    final daily = DailyProgress(
      quizzesToday: quizzes.where((q) => _isToday(q.createdAt)).length,
      notesToday: noteDates.where(_isToday).length,
      summariesToday: summaryDates.where(_isToday).length,
      tasksCompletedToday: completedRemindersToday,
    );

    // ---- Academic health ----
    final double? quizAverage = quizzes.isEmpty
        ? null
        : quizzes
                  .map((q) => q.total == 0 ? 0.0 : q.score / q.total * 100)
                  .reduce((a, b) => a + b) /
              quizzes.length;

    final health = _buildHealth(
      gpa: gpa,
      pendingAssignments: pendingAssignments,
      upcomingExams: upcomingExams,
      quizAveragePercent: quizAverage,
      hasAnyActivity: quizzes.isNotEmpty || noteCount > 0 || chatCount > 0,
    );

    // ---- Study RPG ----
    final int xp =
        quizzes.length * _xpQuiz +
        summaryCount * _xpSummary +
        noteCount * _xpNote +
        chatCount * _xpChat +
        materialCount * _xpMaterial +
        flashcardCount * _xpFlashcard;

    final int level = xp ~/ StudyRpg.xpPerLevel + 1;

    final activityDates = <DateTime>[
      ...quizzes.map((q) => q.createdAt),
      ...noteDates,
      ...summaryDates,
      ...chatDates,
    ];

    final rpg = StudyRpg(
      xp: xp,
      level: level,
      levelFloor: (level - 1) * StudyRpg.xpPerLevel,
      nextLevelAt: level * StudyRpg.xpPerLevel,
      streakDays: _streakFrom(activityDates),
      badges: _badgesFor(
        quizCount: quizzes.length,
        noteCount: noteCount,
        summaryCount: summaryCount,
        flashcardCount: flashcardCount,
        level: level,
      ),
    );

    return LearningStats(daily: daily, health: health, rpg: rpg);
  }

  // -----------------------------------------------------------------------
  // HELPERS
  // -----------------------------------------------------------------------

  static bool _isToday(DateTime when) {
    final now = DateTime.now();
    return when.year == now.year &&
        when.month == now.month &&
        when.day == now.day;
  }

  /// Counts consecutive days with activity, ending today or yesterday
  /// (so an evening-only study habit doesn't reset the streak at midnight).
  static int _streakFrom(List<DateTime> dates) {
    if (dates.isEmpty) return 0;

    final days =
        dates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()
          ..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime cursor;
    if (days.first == today) {
      cursor = today;
    } else if (days.first == yesterday) {
      cursor = yesterday;
    } else {
      return 0; // the streak has already been broken
    }

    int streak = 0;
    for (final day in days) {
      if (day == cursor) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (day.isBefore(cursor)) {
        break;
      }
    }
    return streak;
  }

  static AcademicHealth _buildHealth({
    required double? gpa,
    required int pendingAssignments,
    required int upcomingExams,
    required double? quizAveragePercent,
    required bool hasAnyActivity,
  }) {
    // Start neutral and move up or down on real signals only.
    int score = 2; // 0 = needs attention .. 3 = excellent
    final suggestions = <String>[];

    if (gpa != null) {
      if (gpa >= 3.5) {
        score++;
      } else if (gpa < 2.5) {
        score--;
        suggestions.add(
          'Your GPA is ${gpa.toStringAsFixed(2)} — plan revision time for '
          'your weaker subjects.',
        );
      }
    } else {
      suggestions.add('Add a GPA record so we can track your grade trend.');
    }

    if (pendingAssignments >= 3) {
      score--;
      suggestions.add(
        '$pendingAssignments assignments are pending — start with the '
        'closest deadline.',
      );
    } else if (pendingAssignments > 0) {
      suggestions.add(
        '$pendingAssignments assignment${pendingAssignments == 1 ? '' : 's'} '
        'pending. Keep it up.',
      );
    }

    if (upcomingExams > 0) {
      suggestions.add(
        '$upcomingExams exam${upcomingExams == 1 ? '' : 's'} coming up — a '
        'study roadmap can help you plan.',
      );
    }

    if (quizAveragePercent != null) {
      if (quizAveragePercent >= 75) {
        score++;
      } else if (quizAveragePercent < 50) {
        score--;
        suggestions.add(
          'Quiz average is ${quizAveragePercent.round()}% — try flashcards '
          'on the topics you miss.',
        );
      }
    }

    if (!hasAnyActivity) {
      suggestions.add('Start with a quiz or a note to build your streak.');
    }

    final HealthLevel level;
    if (score >= 4) {
      level = HealthLevel.excellent;
    } else if (score >= 2) {
      level = HealthLevel.good;
    } else if (score >= 1) {
      level = HealthLevel.fair;
    } else {
      level = HealthLevel.needsAttention;
    }

    if (suggestions.isEmpty) {
      suggestions.add('Everything looks on track. Keep up the good work!');
    }

    return AcademicHealth(
      level: level,
      gpa: gpa,
      pendingAssignments: pendingAssignments,
      upcomingExams: upcomingExams,
      quizAveragePercent: quizAveragePercent,
      // Keep the card short.
      suggestions: suggestions.take(2).toList(),
    );
  }

  static List<StudyBadge> _badgesFor({
    required int quizCount,
    required int noteCount,
    required int summaryCount,
    required int flashcardCount,
    required int level,
  }) {
    final badges = <StudyBadge>[];
    if (quizCount >= 1) {
      badges.add(
        const StudyBadge(label: 'First Quiz', icon: Icons.quiz_rounded),
      );
    }
    if (quizCount >= 10) {
      badges.add(
        const StudyBadge(
          label: 'Quiz Master',
          icon: Icons.emoji_events_rounded,
        ),
      );
    }
    if (noteCount >= 5) {
      badges.add(
        const StudyBadge(label: 'Note Taker', icon: Icons.note_alt_rounded),
      );
    }
    if (summaryCount >= 5) {
      badges.add(
        const StudyBadge(label: 'Summarizer', icon: Icons.auto_awesome_rounded),
      );
    }
    if (flashcardCount >= 20) {
      badges.add(
        const StudyBadge(label: 'Card Collector', icon: Icons.style_rounded),
      );
    }
    if (level >= 10) {
      badges.add(
        const StudyBadge(label: 'Scholar', icon: Icons.school_rounded),
      );
    }
    return badges;
  }
}
