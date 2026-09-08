import 'package:flutter/material.dart';

import '../models/study_roadmap.dart';
import '../theme/app_colors.dart';
import '../widgets/animations.dart';

/// ---------------------------------------------------------------------------
/// ROADMAP DETAIL SCREEN
/// Shows one saved AI study roadmap: a gradient header (subject, exam date,
/// days left, skill level, hours) and the full plan text.
/// ---------------------------------------------------------------------------
class RoadmapDetailScreen extends StatelessWidget {
  final StudyRoadmap roadmap;

  const RoadmapDetailScreen({super.key, required this.roadmap});

  String get _examDateText =>
      '${roadmap.examDate.day}/${roadmap.examDate.month}/'
      '${roadmap.examDate.year}';

  String get _daysLeftText {
    final int days = roadmap.daysUntilExam;
    if (days > 1) return '$days days left';
    if (days == 1) return '1 day left';
    if (days == 0) return 'exam is today!';
    return 'exam date passed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Roadmap')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ----- Gradient header -----
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.mainGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.map_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              roadmap.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Exam: $_examDateText  •  $_daysLeftText',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _headerChip(
                            Icons.trending_up_rounded,
                            roadmap.skillLevel,
                          ),
                          const SizedBox(width: 8),
                          _headerChip(
                            Icons.schedule_rounded,
                            '${roadmap.studyHours} hrs/day',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ----- The plan -----
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow(context),
                    border: AppColors.cardBorder(context),
                  ),
                  child: SelectableText(
                    roadmap.roadmap,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: AppColors.text(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
