import 'package:flutter/material.dart';

import '../models/dashboard_stats.dart';
import '../services/history_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_date.dart';
import '../widgets/animations.dart';
import '../widgets/empty_state.dart';

/// ---------------------------------------------------------------------------
/// PROGRESS DASHBOARD (analytics)
/// Shows totals (chats / quizzes / summaries) and the user's most
/// recent AI activity, loaded from Firestore.
/// ---------------------------------------------------------------------------
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  DashboardStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await HistoryService.instance.loadDashboardStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } on HistoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Dashboard')),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.indigo),
              )
            : stats == null
            ? Center(
                child: Text(
                  'Could not load your stats.\nPlease try again later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subText(context)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ----- Header banner -----
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.mainGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.indigo.withValues(alpha: 0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.insights_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Learning Progress',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Everything you have done with Learnova AI',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ----- Totals -----
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.chat_bubble_rounded,
                          value: stats.totalChats,
                          label: 'Chats',
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.quiz_rounded,
                          value: stats.totalQuizzes,
                          label: 'Quizzes',
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.auto_awesome_rounded,
                          value: stats.totalSummaries,
                          label: 'Summaries',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ----- Activity bar chart -----
                    _ActivityBarChart(
                      chats: stats.totalChats,
                      quizzes: stats.totalQuizzes,
                      summaries: stats.totalSummaries,
                    ),
                    const SizedBox(height: 24),

                    // ----- Recent activity -----
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (stats.recentActivity.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.cardShadow(context),
                          border: AppColors.cardBorder(context),
                        ),
                        child: const EmptyState(
                          icon: Icons.bar_chart_rounded,
                          title: 'No activity yet',
                          message:
                              'Try the AI features and your progress will '
                              'appear here.',
                          accent: Color(
                            0xFF6366F1,
                          ), // ModuleAccent.progress.end
                        ),
                      )
                    else
                      for (final item in stats.recentActivity)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppColors.cardShadow(context),
                            border: AppColors.cardBorder(context),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: AppColors.mainGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _iconFor(item.type),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text(context),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      formatDateTime(item.date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.subText(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// One small stat card (icon + number + label).
class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow(context),
          border: AppColors.cardBorder(context),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            CountUpText(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.subText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple bar chart comparing total chats / quizzes / summaries.
/// Built from plain Containers (no chart package), bar heights are scaled to
/// the largest value. Uses only the existing Firestore totals.
class _ActivityBarChart extends StatelessWidget {
  final int chats;
  final int quizzes;
  final int summaries;

  const _ActivityBarChart({
    required this.chats,
    required this.quizzes,
    required this.summaries,
  });

  @override
  Widget build(BuildContext context) {
    final List<({String label, int value, IconData icon})> items = [
      (label: 'Chats', value: chats, icon: Icons.chat_bubble_rounded),
      (label: 'Quizzes', value: quizzes, icon: Icons.quiz_rounded),
      (label: 'Summaries', value: summaries, icon: Icons.auto_awesome_rounded),
    ];
    final int maxValue = items
        .map((i) => i.value)
        .fold(0, (m, v) => v > m ? v : m);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: AppColors.readable(context, AppColors.indigo),
              ),
              const SizedBox(width: 8),
              Text(
                'Activity Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in items)
                  Expanded(
                    child: _bar(context, item.value, item.label, maxValue),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One bar: value on top, gradient bar, label underneath.
  Widget _bar(BuildContext context, int value, String label, int maxValue) {
    const double maxBarHeight = 120;
    // A small floor so a zero / tiny value still shows a visible stub.
    final double barHeight = maxValue == 0
        ? 6
        : 10 + (value / maxValue) * (maxBarHeight - 10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: barHeight,
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: AppColors.subText(context)),
          ),
        ],
      ),
    );
  }
}
