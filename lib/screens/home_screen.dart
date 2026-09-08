import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../models/learning_stats.dart';
import '../models/study_reminder.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/learning_stats_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/accent_icon.dart';
import '../widgets/accent_pill.dart';
import '../widgets/animations.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_progress_bar.dart';
import '../widgets/press_scale.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/skeleton.dart';
import 'main_shell.dart';
import 'reminders_screen.dart';

/// ---------------------------------------------------------------------------
/// HOME SCREEN
/// The main dashboard: greeting, AI assistant card, today's progress, academic
/// health, the study RPG panel and upcoming tasks.
///
/// Every number comes from data the app already stores — see
/// [LearningStatsService]. Nothing here writes to Firestore.
/// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  /// Lets the cards switch the bottom-nav tab (0 Home, 1 Chat, 2 Hub, 3 Profile).
  final ValueChanged<int>? onOpenTab;

  /// Bumped by [MainShell] whenever Home becomes the visible tab.
  ///
  /// The tabs live in a PageView and are kept alive, so returning to Home does
  /// not rebuild it. Without this, a student who records a GPA or finishes a
  /// quiz in the Study Hub comes back to a dashboard still showing the figures
  /// from before, which reads as a broken total rather than a stale one.
  static final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);

  const HomeScreen({super.key, this.onOpenTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Home's own accent (brand blue -> purple).
  static const ModuleAccent _accent = ModuleAccent.home;

  UserProfile? _profile;
  LearningStats _stats = const LearningStats.empty();
  List<StudyReminder> _upcoming = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    HomeScreen.refreshSignal.addListener(_reloadQuietly);
  }

  @override
  void dispose() {
    HomeScreen.refreshSignal.removeListener(_reloadQuietly);
    super.dispose();
  }

  /// Re-reads the figures without showing the skeleton again.
  ///
  /// The cards already hold last-known values, so replacing them with
  /// placeholders for a second would flicker on every return to the tab.
  void _reloadQuietly() {
    if (mounted) _load();
  }

  /// Loads everything the screen shows. Each source fails soft so one error
  /// never blanks the dashboard.
  Future<void> _load() async {
    try {
      final profile = await AuthService.instance.loadProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}

    try {
      final stats = await LearningStatsService.instance.load();
      if (mounted) setState(() => _stats = stats);
      // Carry the top suggestion into tomorrow's notification. The dashboard
      // is the only place the suggestion is worked out, so scheduling it here
      // guarantees the notification and the Academic Health card always say
      // the same thing.
      final List<String> suggestions = stats.health.suggestions;
      await NotificationService.instance.scheduleDailySuggestion(
        suggestions.isEmpty ? '' : suggestions.first,
      );
    } catch (_) {}

    try {
      final reminders = await ReminderService.instance.loadReminders();
      final now = DateTime.now();
      final upcoming =
          reminders
              .where(
                (r) => !r.isCompleted && (r.startAt?.isAfter(now) ?? false),
              )
              .toList()
            ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
      if (mounted) setState(() => _upcoming = upcoming.take(3).toList());
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Accent text stays readable on both themes: lightened on dark backgrounds.
  Color _accentOn(Color color) => AppColors.readable(context, color);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Soft brand blooms behind the cards, matching Profile so the two
      // dashboards read as one app.
      body: BrandBackdrop(
        intensity: 0.7,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.indigo,
            onRefresh: () async {
              setState(() => _loading = true);
              await _load();
            },
            child: ListView(
              // The frosted nav bar floats over the body, so the last card needs
              // clearance to scroll fully clear of it.
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + kBottomNavSpace,
              ),
              children: [
                FadeSlideIn(child: _header()),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child: _aiAssistantCard(),
                ),
                const SizedBox(height: 14),
                // While the first load runs, stand in shaped placeholders rather
                // than cards full of zeros — a "0%" that later jumps to 40%
                // reads as wrong data, a skeleton reads as loading.
                if (_loading)
                  const Shimmer(
                    child: Column(
                      children: [
                        SkeletonCard(lines: 3),
                        SizedBox(height: 14),
                        SkeletonCard(lines: 2),
                        SizedBox(height: 14),
                        SkeletonCard(lines: 2),
                        SizedBox(height: 14),
                        SkeletonCard(lines: 2),
                      ],
                    ),
                  )
                else ...[
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: _progressCard(),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: _healthCard(),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: _rpgCard(),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: _upcomingCard(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 1. HEADER
  // -----------------------------------------------------------------------

  Widget _header() {
    final bool isDark = AppColors.isDark(context);
    return Row(
      children: [
        GestureDetector(
          onTap: () => widget.onOpenTab?.call(3),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.end.withValues(alpha: isDark ? 0.45 : 0.28),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ProfileAvatar(
              radius: 24,
              initials: _profile?.initials ?? 'S',
              bytes: AuthService.instance.localAvatarBytes,
              photoUrl: _profile?.photoUrl ?? '',
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AppColors.subText(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Welcome back, ${_profile?.firstName ?? 'Student'} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        ),
        // Notifications: badge shows how many tasks are coming up.
        _iconButton(
          icon: Icons.notifications_none_rounded,
          badge: _upcoming.length,
          onTap: () => Navigator.of(
            context,
          ).push(smoothRoute(const RemindersScreen())).then((_) => _load()),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          // A small square button, not a card: the card radius would round it
          // almost to a circle.
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cardShadow(context),
          border: AppColors.cardBorder(context),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 22, color: AppColors.text(context)),
            if (badge > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.card(context),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 2. AI ASSISTANT
  // -----------------------------------------------------------------------

  Widget _aiAssistantCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _accent.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accent.start.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Learnova AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...[
            'Ask academic questions',
            'Summarize your notes',
            'Generate practice quizzes',
          ].map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white70,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    line,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.onOpenTab?.call(1),
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: const Text(
                'Start Chat',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.indigo,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 3. TODAY'S PROGRESS
  // -----------------------------------------------------------------------

  Widget _progressCard() {
    final d = _stats.daily;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.today_rounded,
            "Today's Progress",
            ModuleAccent.progress.start,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpText(
                d.percent,
                suffix: '%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'completed',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subText(context),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${d.totalToday} / ${d.goal} tasks',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subText(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _gradientBar(d.fraction, ModuleAccent.progress),
          const SizedBox(height: 16),
          Row(
            children: [
              // Each mini stat wears its own module colour.
              _miniStat(
                'Quizzes',
                d.quizzesToday,
                Icons.quiz_rounded,
                ModuleAccent.quiz.start,
              ),
              _miniStat(
                'Notes',
                d.notesToday,
                Icons.note_alt_rounded,
                ModuleAccent.notes.start,
              ),
              _miniStat(
                'Summaries',
                d.summariesToday,
                Icons.auto_awesome_rounded,
                ModuleAccent.summarizer.start,
              ),
              _miniStat(
                'Tasks',
                d.tasksCompletedToday,
                Icons.check_circle_rounded,
                ModuleAccent.gpa.start,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, IconData icon, [Color? accent]) {
    return Expanded(
      child: Column(
        children: [
          _softIcon(icon, accent ?? AppColors.indigo, size: 32),
          const SizedBox(height: 7),
          CountUpText(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: AppColors.subText(context)),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 4. ACADEMIC HEALTH
  // -----------------------------------------------------------------------

  Widget _healthCard() {
    final h = _stats.health;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardTitle(
                  Icons.favorite_rounded,
                  'Academic Health',
                  h.level.color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: h.level.color.withValues(
                    alpha: AppColors.isDark(context) ? 0.22 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${h.level.label} ${h.level.emoji}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _accentOn(h.level.color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // GPA is out of 4.0; quiz average out of 100. Pending and Exams
              // are counts, so they get no bar — there is nothing to be a
              // proportion of.
              _healthStat(
                'GPA',
                h.gpa == null ? '—' : h.gpa!.toStringAsFixed(2),
                fraction: h.gpa == null ? null : h.gpa! / 4.0,
                accent: ModuleAccent.gpa.end,
              ),
              _healthStat(
                'Pending',
                '${h.pendingAssignments}',
                accent: ModuleAccent.reminders.end,
              ),
              _healthStat(
                'Exams',
                '${h.upcomingExams}',
                accent: ModuleAccent.quiz.end,
              ),
              _healthStat(
                'Quiz avg',
                h.quizAveragePercent == null
                    ? '—'
                    : '${h.quizAveragePercent!.round()}%',
                fraction: h.quizAveragePercent == null
                    ? null
                    : h.quizAveragePercent! / 100.0,
                accent: ModuleAccent.quiz.end,
              ),
            ],
          ),
          if (h.suggestions.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...h.suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: _accentOn(_accent.end),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.subText(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One figure in the health row, on a soft tinted tile with a small coloured
  /// bar beneath it.
  ///
  /// The bar is what turns four bare numbers into a readable set: [fraction]
  /// is how "full" the measure is (GPA out of 4, quiz average out of 100), and
  /// [accent] carries the meaning. Pass a null fraction for counts, where a
  /// proportion would be meaningless — the bar is simply omitted rather than
  /// invented.
  Widget _healthStat(
    String label,
    String value, {
    double? fraction,
    Color? accent,
  }) {
    final bool isDark = AppColors.isDark(context);
    final Color barColor = accent ?? _accent.end;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.subText(context),
              ),
            ),
            if (fraction != null) ...[
              const SizedBox(height: 7),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 5. STUDY RPG
  // -----------------------------------------------------------------------

  Widget _rpgCard() {
    final r = _stats.rpg;
    const ModuleAccent rpgAccent = ModuleAccent.profile;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Level medallion, matching the Profile achievements card.
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: rpgAccent.gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: rpgAccent.end.withValues(alpha: 0.35),
                      blurRadius: 13,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'LVL',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${r.level}',
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.rankName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${r.xp} XP earned',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subText(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (r.streakDays > 0)
                _pill(
                  Icons.local_fire_department_rounded,
                  '${r.streakDays} day${r.streakDays == 1 ? '' : 's'}',
                  const Color(0xFFF97316),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Progress to level ${r.level + 1}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subText(context),
                ),
              ),
              const Spacer(),
              Text(
                '${r.xp - r.levelFloor} / ${r.nextLevelAt - r.levelFloor} XP',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _accentOn(rpgAccent.end),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _gradientBar(r.levelFraction, rpgAccent),
          if (r.badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in r.badges)
                  _pill(badge.icon, badge.label, rpgAccent.end),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 6. UPCOMING TASKS
  // -----------------------------------------------------------------------

  Widget _upcomingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardTitle(
                  Icons.event_note_rounded,
                  'Upcoming Tasks',
                  ModuleAccent.reminders.start,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(smoothRoute(const RemindersScreen()))
                    .then((_) => _load()),
                child: Text(
                  'View all',
                  style: TextStyle(
                    color: _accentOn(_accent.end),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.indigo),
              ),
            )
          else if (_upcoming.isEmpty)
            // A tappable empty state in the module's own colour, rather than a
            // line of grey text — it names the next action and performs it.
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PressScale(
                onTap: () => Navigator.of(context)
                    .push(smoothRoute(const RemindersScreen()))
                    .then((_) => _load()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: ModuleAccent.reminders.end.withValues(
                      alpha: AppColors.isDark(context) ? 0.12 : 0.07,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ModuleAccent.reminders.end.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      _softIcon(
                        Icons.add_alarm_rounded,
                        ModuleAccent.reminders.end,
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nothing scheduled',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Add a reminder to stay on track.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.subText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _accentOn(ModuleAccent.reminders.end),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._upcoming.map(_taskRow),
        ],
      ),
    );
  }

  Widget _taskRow(StudyReminder r) {
    final when = r.startAt!;
    final bool isDark = AppColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: ModuleAccent.reminders.gradient,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: ModuleAccent.reminders.start.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(_iconForKind(r.kind), color: Colors.white, size: 16),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${when.day}/${when.month} · '
                    '${when.hour.toString().padLeft(2, '0')}:'
                    '${when.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.subText(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'assignment':
        return Icons.assignment_rounded;
      case 'exam':
        return Icons.school_rounded;
      case 'timetable':
        return Icons.schedule_rounded;
      default:
        return Icons.alarm_rounded;
    }
  }

  // -----------------------------------------------------------------------
  // SHARED
  // -----------------------------------------------------------------------

  /// Frosted dashboard card.
  ///
  /// blur 0: the translucent tint and hairline highlight are what read as
  /// glass — the BackdropFilter is the expensive part, and a scrolling list of
  /// blurring cards is far too costly on a software-rendered emulator.
  Widget _card({required Widget child}) {
    return GlassCard(
      blur: 0,
      elevated: true,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  Widget _cardTitle(IconData icon, String title, [Color? accent]) {
    return Row(
      children: [
        _softIcon(icon, accent ?? AppColors.indigo),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Soft tinted icon tile. Delegates to the shared [AccentIcon] so Home,
  /// Profile and the AI screens all use one implementation.
  Widget _softIcon(IconData icon, Color color, {double size = 34}) =>
      AccentIcon(icon: icon, color: color, size: size);

  /// Small rounded pill used for the streak and earned badges.
  Widget _pill(IconData icon, String label, Color color) =>
      AccentPill(icon: icon, label: label, color: color);

  /// Rounded progress bar that fills on first show, in the module's own
  /// gradient rather than a flat colour.
  Widget _gradientBar(double fraction, ModuleAccent accent) =>
      GradientProgressBar(value: fraction, accent: accent);
}
