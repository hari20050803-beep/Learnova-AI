import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../models/gpa_record.dart';
import '../models/learning_stats.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/gpa_service.dart';
import '../services/history_service.dart';
import '../services/learning_stats_service.dart';
import '../services/material_service.dart';
import '../services/note_service.dart';
import '../services/notification_service.dart';
import '../services/password_reset_service.dart';
import '../services/preferences_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/smooth_route.dart';
import '../widgets/accent_icon.dart';
import '../widgets/accent_pill.dart';
import '../widgets/animations.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_progress_bar.dart';
import '../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'notification_settings_screen.dart';
import 'reset_otp_screen.dart';

/// ---------------------------------------------------------------------------
/// PROFILE / SETTINGS SCREEN
/// Real Firebase user data, edit profile + avatar, activity statistics,
/// student information, Study RPG achievements, and grouped settings
/// (preferences, account, app).
///
/// Every number on this screen is DERIVED from data the app already stores —
/// nothing is invented, and nothing new is written back to Firestore.
/// ---------------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// The Profile tab's own accent, used for the cover, avatar glow and XP bar.
  static const ModuleAccent _accent = ModuleAccent.profile;

  UserProfile? _profile;
  bool _loading = true;

  // Activity statistics.
  int _chats = 0;
  int _quizzes = 0;
  int _summaries = 0;
  int _notes = 0;
  int _materials = 0;
  int _reminders = 0;
  GpaRecord? _latestGpa;

  /// Level / XP / streak / badges, built from the same activity data.
  StudyRpg _rpg = const StudyRpg.empty();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // DATA LOADING
  // -----------------------------------------------------------------------

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.instance.loadProfile();
      if (mounted) setState(() => _profile = profile);
    } on AuthException {
      // Fall back to the basic auth info so the screen still works offline.
      final user = AuthService.instance.currentUser;
      if (mounted) {
        setState(() {
          _profile = UserProfile(
            uid: user?.uid ?? '',
            fullName: user?.displayName ?? '',
            email: user?.email ?? '',
            createdAt: user?.metadata.creationTime,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Loads the activity counts. Each source is independent, so one failure
  /// never blocks the others (the cards just stay at their last value).
  Future<void> _loadStats() async {
    try {
      final stats = await HistoryService.instance.loadDashboardStats();
      if (mounted) {
        setState(() {
          _chats = stats.totalChats;
          _quizzes = stats.totalQuizzes;
          _summaries = stats.totalSummaries;
        });
      }
    } on HistoryException {
      // ignore — stats are optional
    }
    try {
      final notes = await NoteService.instance.loadSummary();
      if (mounted) setState(() => _notes = notes.total);
    } on NoteException {
      // ignore
    }
    try {
      final materials = await MaterialService.instance.loadSummary();
      if (mounted) setState(() => _materials = materials.total);
    } on MaterialException {
      // ignore
    }
    try {
      final reminders = await ReminderService.instance.loadReminders();
      if (mounted) setState(() => _reminders = reminders.length);
    } on ReminderException {
      // ignore
    }
    try {
      final gpa = await GpaService.instance.loadLatest();
      if (mounted) setState(() => _latestGpa = gpa);
    } on GpaException {
      // ignore
    }
    // Level / XP / streak / badges. The service already fails soft on every
    // source, so an empty result simply leaves the card at level 1.
    try {
      final learning = await LearningStatsService.instance.load();
      if (mounted) setState(() => _rpg = learning.rpg);
    } catch (_) {
      // ignore — achievements are optional
    }
  }

  // -----------------------------------------------------------------------
  // ACTIONS
  // -----------------------------------------------------------------------

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final bool? changed = await Navigator.of(
      context,
    ).push<bool>(smoothRoute(EditProfileScreen(profile: profile)));
    if (changed == true) _loadProfile();
  }

  /// One line describing the current notification setup, e.g.
  /// "Enabled · Classes, Assignments" — so Profile shows the state without
  /// duplicating the switches.
  String _notificationSummary(bool enabled) {
    if (!enabled) return 'All reminders are off';

    final prefs = PreferencesService.instance;
    final active = <String>[
      if (prefs.notifyStudySessions) 'Classes',
      if (prefs.notifyAssignments) 'Assignments',
      if (prefs.notifyExams) 'Exams',
      if (prefs.notifyAiSuggestions) 'AI tips',
    ];
    if (active.isEmpty) return 'Enabled · no categories selected';
    if (active.length == 4) return 'Enabled · all reminders active';
    return 'Enabled · ${active.join(', ')}';
  }

  /// Changes the password without leaving the application.
  ///
  /// It uses the same three steps as Forgot Password — code to the address on
  /// the account, then the reset screen — rather than emailing a link. A
  /// signed-in student could in principle be asked for the old password
  /// instead, but somebody who has forgotten it is exactly who needs this, and
  /// one flow is easier to trust than two.
  Future<void> _changePassword() async {
    final String email = _profile?.email ?? '';
    if (email.isEmpty) {
      _showMessage('No email is linked to this account.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Text(
          'We will email a 6-digit code to:\n\n$email\n\n'
          'Enter it on the next screen and choose your new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send code'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await PasswordResetService.instance.requestCode(email);
      if (!mounted) return;
      _showMessage('Code sent to $email', isError: false);
      Navigator.of(context).push(smoothRoute(ResetOtpScreen(email: email)));
    } on PasswordResetException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to use Learnova AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(smoothRoute(const LoginScreen()), (route) => false);
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Learnova AI',
      applicationVersion: 'Version 1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/learnova_logo.png',
          width: 48,
          height: 48,
        ),
      ),
      children: [
        const SizedBox(height: 8),
        const Text(
          'Learnova AI is your AI-powered student academic assistant — '
          'notes, summaries, quizzes, an academic chatbot, GPA tracking, '
          'study reminders and more, all in one place.',
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      // Soft brand blooms behind the content, so the frosted cards have
      // something to sit against instead of a flat surface.
      body: BrandBackdrop(
        intensity: 0.7,
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.indigo),
                )
              : ListView(
                  // Clearance for the frosted nav bar floating over the body.
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    28 + kBottomNavSpace,
                  ),
                  children: [
                    FadeSlideIn(child: _profileHeader()),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: GradientButton(
                        text: 'Edit Profile',
                        onPressed: _openEditProfile,
                      ),
                    ),
                    const SizedBox(height: 26),

                    _section('YOUR ACTIVITY', 110, _activityCards()),
                    _section('STUDENT INFORMATION', 170, _studentInfoCard()),
                    _section('ACHIEVEMENTS', 230, _rpgCard()),
                    _section('PREFERENCES', 290, _preferencesGroup()),
                    _section('ACCOUNT', 350, _accountGroup()),
                    _section('APP', 410, _appGroup(), last: true),
                  ],
                ),
        ),
      ),
    );
  }

  /// A titled block that fades and slides in together, staggered by [delayMs].
  Widget _section(
    String title,
    int delayMs,
    Widget child, {
    bool last = false,
  }) {
    return FadeSlideIn(
      delay: Duration(milliseconds: delayMs),
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_sectionTitle(title), child],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 1. PROFILE HEADER
  // -----------------------------------------------------------------------

  Widget _profileHeader() {
    final profile = _profile!;
    const double coverHeight = 88;
    const double avatarRadius = 46;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Gradient cover with the avatar hanging over its bottom edge. The
          // Stack sizes itself to the taller child, so the avatar's lower half
          // naturally sits on the card background below.
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: coverHeight,
                width: double.infinity,
                decoration: const BoxDecoration(gradient: _accentGradient),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: coverHeight - avatarRadius - 6,
                ),
                child: _glowAvatar(profile, avatarRadius),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              children: [
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  profile.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subText(context),
                  ),
                ),
                const SizedBox(height: 14),
                // Student badge + live rank, side by side.
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badgePill(
                      Icons.school_rounded,
                      'Student',
                      _accent.end,
                      filled: true,
                    ),
                    _badgePill(
                      Icons.workspace_premium_rounded,
                      'Level ${_rpg.level}  •  ${_rpg.rankName}',
                      _accent.end,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The gradient of [_accent] as a const, so the cover can be a const
  /// decoration.
  static const LinearGradient _accentGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Large avatar with a coloured glow, a card-coloured ring so it separates
  /// from the gradient cover, and the edit-avatar button.
  Widget _glowAvatar(UserProfile profile, double radius) {
    final bool isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: _openEditProfile,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.end.withValues(alpha: isDark ? 0.55 : 0.38),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ProfileAvatar(
              radius: radius,
              initials: profile.initials,
              bytes: AuthService.instance.localAvatarBytes,
              photoUrl: profile.photoUrl,
              // Flies into the Edit Profile avatar — a real route push.
              heroTag: kProfileAvatarHeroTag,
            ),
          ),
          // Edit avatar button.
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: _accent.gradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.card(context), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }

  /// Small rounded pill. [filled] uses the accent as the background, otherwise
  /// it is a soft tint — keeps the header from becoming too colourful.
  ///
  /// Delegates to the shared [AccentPill] so Home and Profile use one
  /// implementation.
  Widget _badgePill(
    IconData icon,
    String label,
    Color color, {
    bool filled = false,
  }) => AccentPill(icon: icon, label: label, color: color, filled: filled);

  /// Accent text stays readable on both themes: lightened on dark backgrounds.
  Color _pillText(Color color, bool isDark) =>
      AppColors.readable(context, color);

  // -----------------------------------------------------------------------
  // 2. ACTIVITY STATISTICS (real Firestore data)
  // -----------------------------------------------------------------------

  Widget _activityCards() {
    return Column(
      children: [
        // The three the student cares about most, given the most room.
        Row(
          children: [
            Expanded(
              child: _highlightStat(
                Icons.note_alt_rounded,
                'Notes',
                _notes,
                ModuleAccent.notes,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _highlightStat(
                Icons.quiz_rounded,
                'Quizzes',
                _quizzes,
                ModuleAccent.quiz,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _highlightStat(
                Icons.smart_toy_rounded,
                'AI Chats',
                _chats,
                ModuleAccent.chatbot,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _statsGrid(),
      ],
    );
  }

  /// Tall stat card with the number counting up on first show.
  Widget _highlightStat(
    IconData icon,
    String label,
    int value,
    ModuleAccent accent,
  ) {
    return GlassCard(
      blur: 0,
      elevated: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: accent.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.end.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(height: 10),
          CountUpText(
            value,
            style: TextStyle(
              fontSize: 21,
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
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.subText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final tiles = <Widget>[
      // Each tile wears its module accent, matching Home and Study Hub.
      _statCard(
        Icons.auto_awesome_rounded,
        'Summaries',
        '$_summaries',
        ModuleAccent.summarizer,
      ),
      _statCard(
        Icons.menu_book_rounded,
        'Materials',
        '$_materials',
        ModuleAccent.materials,
      ),
      _statCard(
        Icons.alarm_rounded,
        'Reminders',
        '$_reminders',
        ModuleAccent.reminders,
      ),
      _statCard(
        Icons.calculate_rounded,
        'Latest GPA',
        _latestGpa == null ? '—' : _latestGpa!.gpa.toStringAsFixed(2),
        ModuleAccent.gpa,
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.85,
      children: tiles,
    );
  }

  Widget _statCard(
    IconData icon,
    String label,
    String value, [
    ModuleAccent? accent,
  ]) {
    return GlassCard(
      blur: 0,
      elevated: true,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: accent?.gradient ?? AppColors.mainGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  // -----------------------------------------------------------------------
  // 3. STUDENT INFORMATION
  // -----------------------------------------------------------------------

  Widget _studentInfoCard() {
    final profile = _profile!;
    return GlassCard(
      blur: 0,
      elevated: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          _infoRow(
            Icons.account_balance_rounded,
            'University',
            profile.university,
            ModuleAccent.materials,
          ),
          _infoDivider(),
          _infoRow(
            Icons.menu_book_rounded,
            'Course',
            profile.course,
            ModuleAccent.roadmap,
          ),
          _infoDivider(),
          _infoRow(
            Icons.wc_rounded,
            'Gender',
            profile.gender,
            ModuleAccent.summarizer,
          ),
          _infoDivider(),
          _infoRow(
            Icons.location_on_rounded,
            'Address',
            profile.address,
            ModuleAccent.reminders,
          ),
          _infoDivider(),
          _infoRow(
            Icons.calendar_month_rounded,
            'Joined',
            _joinedLabel(profile.createdAt),
            ModuleAccent.progress,
          ),
        ],
      ),
    );
  }

  /// One label / value line. An empty value shows a muted hint instead of a
  /// blank space, so the student can see what is still missing.
  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    ModuleAccent accent,
  ) {
    final bool empty = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _softIcon(icon, accent.end),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.subText(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  empty ? 'Not added yet' : value.trim(),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
                    fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                    color: empty
                        ? AppColors.subText(context)
                        : AppColors.text(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() => _divider();

  String _joinedLabel(DateTime? date) {
    if (date == null) return '';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  // -----------------------------------------------------------------------
  // 4. STUDY RPG ACHIEVEMENTS
  // -----------------------------------------------------------------------

  Widget _rpgCard() {
    final r = _rpg;
    final bool isDark = AppColors.isDark(context);

    // The achievements panel is frosted — it sits over the brand backdrop, so
    // the tint and highlight give it a lit, glassy feel against the blooms.
    return GlassCard(
      blur: 0,
      elevated: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Level medallion.
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _accent.gradient,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.end.withValues(alpha: 0.35),
                      blurRadius: 14,
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
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${r.level}',
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.rankName,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${r.xp} XP earned',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.subText(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Streak.
              _badgePill(
                Icons.local_fire_department_rounded,
                '${r.streakDays} day${r.streakDays == 1 ? '' : 's'}',
                const Color(0xFFF97316),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // XP progress towards the next level.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress to level ${r.level + 1}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subText(context),
                ),
              ),
              Text(
                '${r.xp - r.levelFloor} / ${r.nextLevelAt - r.levelFloor} XP',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _pillText(_accent.end, isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _xpBar(r.levelFraction),
          const SizedBox(height: 18),

          Text(
            'BADGES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.subText(context),
            ),
          ),
          const SizedBox(height: 10),
          if (r.badges.isEmpty)
            Text(
              'No badges yet — take a quiz or write a note to earn your first.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: AppColors.subText(context),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in r.badges)
                  _badgePill(badge.icon, badge.label, _accent.end),
              ],
            ),
        ],
      ),
    );
  }

  /// Rounded XP bar that fills on first show. Shares [GradientProgressBar]
  /// with Home's progress and XP bars.
  Widget _xpBar(double fraction) => GradientProgressBar(
    value: fraction,
    accent: _accent,
    duration: const Duration(milliseconds: 900),
  );

  // -----------------------------------------------------------------------
  // 5. SETTINGS — PREFERENCES / ACCOUNT / APP
  // -----------------------------------------------------------------------

  Widget _preferencesGroup() {
    final bool isDark = themeNotifier.value == ThemeMode.dark;
    return _card(
      Column(
        children: [
          SwitchListTile(
            value: isDark,
            onChanged: (enabled) {
              setState(() {
                themeNotifier.value = enabled
                    ? ThemeMode.dark
                    : ThemeMode.light;
              });
            },
            activeTrackColor: AppColors.indigo,
            secondary: _softIcon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              _accent.end,
            ),
            title: _tileTitle('Dark Mode'),
            subtitle: _tileSubtitle(
              isDark ? 'Dark theme is on' : 'Light theme is on',
            ),
          ),
          _divider(),
          // Summary only — the switches live on the Notifications screen, so
          // there is one place to change them rather than two that can drift.
          ValueListenableBuilder<bool>(
            valueListenable: NotificationService.instance.notificationsEnabled,
            builder: (context, enabled, _) {
              return ListTile(
                onTap: () async {
                  await Navigator.of(
                    context,
                  ).push(smoothRoute(const NotificationSettingsScreen()));
                  // The screen may have changed a category, so refresh the
                  // summary line.
                  if (mounted) setState(() {});
                },
                leading: _softIcon(
                  enabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  ModuleAccent.reminders.end,
                ),
                title: _tileTitle('Notifications'),
                subtitle: _tileSubtitle(_notificationSummary(enabled)),
                trailing: _chevron(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _accountGroup() {
    return _card(
      Column(
        children: [
          ListTile(
            onTap: _openEditProfile,
            leading: _softIcon(Icons.person_rounded, _accent.end),
            title: _tileTitle('Edit Profile'),
            subtitle: _tileSubtitle('Name, photo, course and university'),
            trailing: _chevron(),
          ),
          _divider(),
          ListTile(
            onTap: _changePassword,
            leading: _softIcon(
              Icons.lock_reset_rounded,
              ModuleAccent.progress.end,
            ),
            title: _tileTitle('Change Password'),
            subtitle: _tileSubtitle('Get a code and set a new one'),
            trailing: _chevron(),
          ),
          _divider(),
          ListTile(
            onTap: _logout,
            leading: _softIcon(Icons.logout_rounded, const Color(0xFFEF4444)),
            title: Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _pillText(
                  const Color(0xFFEF4444),
                  AppColors.isDark(context),
                ),
              ),
            ),
            subtitle: _tileSubtitle('Sign out of this device'),
            trailing: _chevron(),
          ),
        ],
      ),
    );
  }

  Widget _appGroup() {
    return _card(
      ListTile(
        onTap: _showAbout,
        leading: _softIcon(
          Icons.info_outline_rounded,
          ModuleAccent.flashcards.end,
        ),
        title: _tileTitle('About Learnova AI'),
        subtitle: _tileSubtitle('Learnova AI  •  Version 1.0.0'),
        trailing: _chevron(),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // SMALL UI HELPERS (keep the theme consistent)
  // -----------------------------------------------------------------------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.subText(context),
        ),
      ),
    );
  }

  /// Frosted surface used for the grouped settings rows.
  ///
  /// [GlassCard] with blur 0: the translucent tint and hairline highlight are
  /// what read as glass, while the BackdropFilter is the expensive part — and
  /// a scrolling list of blurring cards is far too costly, especially when the
  /// emulator falls back to software rendering.
  ///
  /// The inner Material is still needed: ListTiles paint their own ink and
  /// warn without one.
  Widget _card(Widget child) {
    return GlassCard(
      blur: 0,
      elevated: true,
      borderRadius: BorderRadius.circular(20),
      child: Material(color: Colors.transparent, child: child),
    );
  }

  /// Soft tinted icon tile. Calmer than a full gradient, so long lists of
  /// settings rows do not turn the screen into a rainbow.
  ///
  /// Delegates to the shared [AccentIcon].
  Widget _softIcon(IconData icon, Color color) =>
      AccentIcon(icon: icon, color: color, size: 38);

  Widget _chevron() =>
      Icon(Icons.chevron_right_rounded, color: AppColors.subText(context));

  Widget _tileTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.text(context),
      ),
    );
  }

  Widget _tileSubtitle(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: AppColors.subText(context)),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.isDark(context)
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}
