import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../services/flashcard_service.dart';
import '../services/history_service.dart';
import '../services/note_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/animations.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/press_scale.dart';
import 'flashcards_screen.dart';
import 'gpa_screen.dart';
import 'main_shell.dart';
import 'materials_screen.dart';
import 'notes_screen.dart';
import 'progress_screen.dart';
import 'quiz_screen.dart';
import 'reminders_screen.dart';
import 'roadmap_screen.dart';
import 'summarizer_screen.dart';

/// One titled group of tools in the hub.
class _ToolGroup {
  final String title;
  final List<FeatureType> types;

  const _ToolGroup(this.title, this.types);
}

/// Study Hub's accent as a const gradient, so the AppBar's flexibleSpace can
/// be one. Mirrors [ModuleAccent.studyHub].
const LinearGradient _accentGradient = LinearGradient(
  colors: [Color(0xFF22C55E), Color(0xFF14B8A6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// ---------------------------------------------------------------------------
/// STUDY HUB
/// Every learning tool in one place. Reuses the existing Feature model and
/// DashboardCard, so each card looks and behaves exactly as before — the
/// grouping, the live counts in the hero and the entrance animations are what
/// is new. The AI chatbot and Profile live in their own tabs, so they are
/// deliberately left out here.
///
/// The three hero numbers are read from the services the app already uses —
/// nothing is invented, and nothing new is written to Firestore.
/// ---------------------------------------------------------------------------
class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key});

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  /// Study Hub = learning progress green.
  static const ModuleAccent _accent = ModuleAccent.studyHub;

  /// The tools, grouped by what the student is trying to do.
  static const List<_ToolGroup> _groups = [
    _ToolGroup('MY CONTENT', [FeatureType.notes, FeatureType.materials]),
    _ToolGroup('AI STUDY TOOLS', [
      FeatureType.summarizer,
      FeatureType.quiz,
      FeatureType.flashcards,
      FeatureType.roadmap,
    ]),
    _ToolGroup('PLAN & TRACK', [
      FeatureType.reminders,
      FeatureType.gpa,
      FeatureType.progress,
    ]),
  ];

  // Live counts shown in the hero.
  int _notes = 0;
  int _quizzes = 0;
  int _flashcards = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  /// Each source is independent, so one failure never blanks the others —
  /// the hero simply keeps showing 0 for that one.
  Future<void> _loadCounts() async {
    try {
      final notes = await NoteService.instance.loadSummary();
      if (mounted) setState(() => _notes = notes.total);
    } on NoteException {
      // ignore — counts are optional
    }
    try {
      final stats = await HistoryService.instance.loadDashboardStats();
      if (mounted) setState(() => _quizzes = stats.totalQuizzes);
    } on HistoryException {
      // ignore
    }
    try {
      final cards = await FlashcardService.instance.loadFlashcards();
      if (mounted) setState(() => _flashcards = cards.length);
    } on FlashcardException {
      // ignore
    }
  }

  Widget _screenFor(FeatureType type) {
    switch (type) {
      case FeatureType.notes:
        return const NotesScreen();
      case FeatureType.quiz:
        return const QuizScreen();
      case FeatureType.flashcards:
        return const FlashcardsScreen();
      case FeatureType.materials:
        return const MaterialsScreen();
      case FeatureType.reminders:
        return const RemindersScreen();
      case FeatureType.gpa:
        return const GpaScreen();
      case FeatureType.summarizer:
        return const SummarizerScreen();
      case FeatureType.roadmap:
        return const RoadmapScreen();
      case FeatureType.progress:
        return const ProgressScreen();
      default:
        return const NotesScreen();
    }
  }

  /// Pulls the real Feature entry so titles, icons, descriptions and accents
  /// stay defined in one place.
  Feature _featureFor(FeatureType type) =>
      features.firstWhere((f) => f.type == type, orElse: () => features.first);

  @override
  Widget build(BuildContext context) {
    // Running index across every group, so the entrance stagger flows down
    // the page instead of restarting at each section.
    int cardIndex = 0;
    final List<Widget> sections = [];

    for (final group in _groups) {
      final int titleDelay = 110 + cardIndex * 55;
      sections.add(
        FadeSlideIn(
          delay: Duration(milliseconds: titleDelay),
          child: _sectionTitle(group.title),
        ),
      );
      // An odd-sized group would leave a hole in the last row of a 2-column
      // grid, so its final card is pulled out and given the full width.
      final bool hasOrphan = group.types.length.isOdd;
      final List<FeatureType> gridTypes = hasOrphan
          ? group.types.sublist(0, group.types.length - 1)
          : group.types;

      if (gridTypes.isNotEmpty) {
        sections.add(
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            // Now that the card lays out as one block (icon + text together)
            // rather than being split by a Spacer, it needs less height.
            childAspectRatio: 1.15,
            children: [
              for (final type in gridTypes)
                FadeSlideIn(
                  delay: Duration(milliseconds: 140 + (cardIndex++) * 55),
                  child: _toolCard(type),
                ),
            ],
          ),
        );
      }

      if (hasOrphan) {
        if (gridTypes.isNotEmpty) sections.add(const SizedBox(height: 14));
        sections.add(
          FadeSlideIn(
            delay: Duration(milliseconds: 140 + (cardIndex++) * 55),
            child: _wideToolCard(group.types.last),
          ),
        );
      }

      sections.add(const SizedBox(height: 26));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Study Hub',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        // The module's own green instead of the flat brand indigo, which
        // clashed with the green hero directly beneath it.
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _accentGradient),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _accent.end,
          onRefresh: _loadCounts,
          child: ListView(
            // Always scrollable, so the pull gesture works even when the list
            // is shorter than the screen.
            physics: const AlwaysScrollableScrollPhysics(),
            // Clearance for the frosted nav bar the shell floats over the body.
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + kBottomNavSpace,
            ),
            children: [
              FadeSlideIn(child: _hero()),
              const SizedBox(height: 26),
              ...sections,
            ],
          ),
        ),
      ),
    );
  }

  /// The odd card out, laid out horizontally across the full width.
  ///
  /// Same data, same tap target, same Hero — only the arrangement differs, so
  /// a group with an odd number of tools has no empty cell.
  Widget _wideToolCard(FeatureType type) {
    final feature = _featureFor(type);
    return PressScale(
      onTap: () =>
          Navigator.of(context).push(smoothRoute(_screenFor(feature.type))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow(context),
          border: AppColors.cardBorder(context),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Hero(
              tag: moduleHeroTag(type),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: feature.accent.gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: feature.accent.start.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(feature.icon, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feature.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feature.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: AppColors.subText(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subText(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolCard(FeatureType type) {
    final feature = _featureFor(type);
    return DashboardCard(
      feature: feature,
      // The icon tile flies from this card into the module screen's header.
      // Tags are unique per type, and each type appears once in the hub.
      heroTag: moduleHeroTag(type),
      onTap: () =>
          Navigator.of(context).push(smoothRoute(_screenFor(feature.type))),
    );
  }

  // -----------------------------------------------------------------------
  // HERO — gradient header with live counts
  // -----------------------------------------------------------------------

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _accent.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accent.start.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Frosted icon tile.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your learning tools',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Notes, quizzes, flashcards, reminders and more — all '
                      'in one place.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 14),
          // What the student has built so far, straight from Firestore.
          Row(
            children: [
              _heroStat('Notes', _notes),
              _heroDivider(),
              _heroStat('Quizzes', _quizzes),
              _heroDivider(),
              _heroStat('Flashcards', _flashcards),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          CountUpText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
    width: 1,
    height: 30,
    color: Colors.white.withValues(alpha: 0.22),
  );

  /// Section heading with a short accent bar.
  ///
  /// The label alone floated with no tie to the grid beneath it; the bar
  /// anchors it and carries the module colour without adding another card.
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 4, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              gradient: _accent.gradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.subText(context),
            ),
          ),
        ],
      ),
    );
  }
}
