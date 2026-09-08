import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// LEARNING STATS MODELS
/// Everything the new Home screen shows. All of it is DERIVED from data the
/// app already stores in Firestore (quizzes, notes, summaries, chats,
/// materials, reminders, GPA, flashcards) — nothing here is invented, and
/// nothing new is written back.
/// ---------------------------------------------------------------------------

/// How today is going. [goal] is the number of study actions that counts as
/// a full day.
class DailyProgress {
  final int quizzesToday;
  final int notesToday;
  final int summariesToday;
  final int tasksCompletedToday;
  final int goal;

  const DailyProgress({
    required this.quizzesToday,
    required this.notesToday,
    required this.summariesToday,
    required this.tasksCompletedToday,
    this.goal = 5,
  });

  const DailyProgress.empty()
    : quizzesToday = 0,
      notesToday = 0,
      summariesToday = 0,
      tasksCompletedToday = 0,
      goal = 5;

  int get totalToday =>
      quizzesToday + notesToday + summariesToday + tasksCompletedToday;

  /// 0..1, capped at 1.
  double get fraction =>
      goal == 0 ? 0 : (totalToday / goal).clamp(0.0, 1.0).toDouble();

  int get percent => (fraction * 100).round();
}

/// Overall academic standing.
enum HealthLevel { excellent, good, fair, needsAttention }

extension HealthLevelDisplay on HealthLevel {
  String get label {
    switch (this) {
      case HealthLevel.excellent:
        return 'Excellent';
      case HealthLevel.good:
        return 'Good';
      case HealthLevel.fair:
        return 'Fair';
      case HealthLevel.needsAttention:
        return 'Needs Attention';
    }
  }

  String get emoji {
    switch (this) {
      case HealthLevel.excellent:
      case HealthLevel.good:
        return '🟢';
      case HealthLevel.fair:
        return '🟠';
      case HealthLevel.needsAttention:
        return '🔴';
    }
  }

  Color get color {
    switch (this) {
      case HealthLevel.excellent:
        return const Color(0xFF1E88E5);
      case HealthLevel.good:
        return const Color(0xFF2E9E4F);
      case HealthLevel.fair:
        return const Color(0xFFF57C00);
      case HealthLevel.needsAttention:
        return const Color(0xFFE53935);
    }
  }
}

/// Smart academic risk check, built from GPA, assignments and activity.
class AcademicHealth {
  final HealthLevel level;

  /// Null when the student has not saved a GPA yet.
  final double? gpa;
  final int pendingAssignments;
  final int upcomingExams;

  /// Average quiz score as a percentage, null when no quiz has been taken.
  final double? quizAveragePercent;

  /// Short, friendly pointers shown under the status.
  final List<String> suggestions;

  const AcademicHealth({
    required this.level,
    required this.gpa,
    required this.pendingAssignments,
    required this.upcomingExams,
    required this.quizAveragePercent,
    required this.suggestions,
  });

  const AcademicHealth.empty()
    : level = HealthLevel.good,
      gpa = null,
      pendingAssignments = 0,
      upcomingExams = 0,
      quizAveragePercent = null,
      suggestions = const [];
}

/// Gamification: level, XP, streak and badges earned from real activity.
class StudyRpg {
  final int xp;
  final int level;

  /// XP at the start of the current level, and at the next one.
  final int levelFloor;
  final int nextLevelAt;

  /// Consecutive days (ending today or yesterday) with at least one action.
  final int streakDays;
  final List<StudyBadge> badges;

  const StudyRpg({
    required this.xp,
    required this.level,
    required this.levelFloor,
    required this.nextLevelAt,
    required this.streakDays,
    required this.badges,
  });

  const StudyRpg.empty()
    : xp = 0,
      level = 1,
      levelFloor = 0,
      nextLevelAt = xpPerLevel,
      streakDays = 0,
      badges = const [];

  /// XP needed to move up one level.
  static const int xpPerLevel = 250;

  /// Progress through the current level, 0..1.
  double get levelFraction {
    final int span = nextLevelAt - levelFloor;
    if (span <= 0) return 0;
    return ((xp - levelFloor) / span).clamp(0.0, 1.0).toDouble();
  }

  /// Friendly rank name that grows with the level.
  String get rankName {
    if (level >= 20) return 'Master Scholar';
    if (level >= 12) return 'Scholar';
    if (level >= 8) return 'Achiever';
    if (level >= 4) return 'Learner';
    return 'Beginner';
  }
}

/// One earned badge.
class StudyBadge {
  final String label;
  final IconData icon;

  const StudyBadge({required this.label, required this.icon});
}

/// Everything the Home screen needs, loaded in one go.
class LearningStats {
  final DailyProgress daily;
  final AcademicHealth health;
  final StudyRpg rpg;

  const LearningStats({
    required this.daily,
    required this.health,
    required this.rpg,
  });

  const LearningStats.empty()
    : daily = const DailyProgress.empty(),
      health = const AcademicHealth.empty(),
      rpg = const StudyRpg.empty();
}
