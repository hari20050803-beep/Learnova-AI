/// One row in the "Recent Activity" list of the Progress Dashboard.
class ActivityItem {
  /// 'chat', 'quiz' or 'summary' (decides which icon to show).
  final String type;
  final String title;
  final DateTime date;

  const ActivityItem({
    required this.type,
    required this.title,
    required this.date,
  });
}

/// All numbers shown on the Progress Dashboard screen.
class DashboardStats {
  final int totalChats;
  final int totalQuizzes;
  final int totalSummaries;
  final List<ActivityItem> recentActivity;

  const DashboardStats({
    required this.totalChats,
    required this.totalQuizzes,
    required this.totalSummaries,
    required this.recentActivity,
  });
}
