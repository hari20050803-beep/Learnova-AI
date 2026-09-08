import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../services/learning_stats_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_colors.dart';
import '../widgets/accent_icon.dart';
import '../widgets/animations.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_header.dart';

/// ---------------------------------------------------------------------------
/// NOTIFICATION SETTINGS
/// The full notification controls, opened from the summary row on Profile.
///
/// Every switch here maps onto something the app actually schedules — the
/// reminder kinds ('timetable' / 'study' -> classes and sessions,
/// 'assignment', 'exam') and the one daily study suggestion the dashboard
/// derives from the student's own record — so turning one off genuinely stops
/// those alarms. Choices are saved with [PreferencesService] — the same
/// on-device storage the theme and master toggle already use — and applied by
/// re-scheduling every active reminder.
/// ---------------------------------------------------------------------------
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const ModuleAccent _accent = ModuleAccent.reminders;

  final PreferencesService _prefs = PreferencesService.instance;

  late bool _study = _prefs.notifyStudySessions;
  late bool _assignments = _prefs.notifyAssignments;
  late bool _exams = _prefs.notifyExams;
  late bool _suggestions = _prefs.notifyAiSuggestions;

  /// True while alarms are being re-written after a change.
  bool _applying = false;

  /// Re-schedules every active reminder so the new choices take effect
  /// immediately, instead of only applying to reminders edited later.
  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      final reminders = await ReminderService.instance.loadReminders();
      await NotificationService.instance.rescheduleAll(reminders);
    } on ReminderException {
      // Scheduling is best-effort: the preference is already saved, and the
      // next reminder edit will pick it up.
    } finally {
      await _applySuggestion();
      if (mounted) setState(() => _applying = false);
    }
  }

  /// Re-writes the daily suggestion notification.
  ///
  /// The text has to be fetched rather than remembered, because the suggestion
  /// is worked out from the student's current record. Turning the switch back
  /// on therefore schedules today's advice, not whatever was true when the
  /// switch was last touched.
  Future<void> _applySuggestion() async {
    final bool masterOn =
        NotificationService.instance.notificationsEnabled.value;
    if (!masterOn || !_suggestions) {
      await NotificationService.instance.cancelSuggestion();
      return;
    }
    try {
      final stats = await LearningStatsService.instance.load();
      final List<String> lines = stats.health.suggestions;
      await NotificationService.instance.scheduleDailySuggestion(
        lines.isEmpty ? '' : lines.first,
      );
    } catch (_) {
      // Same best-effort rule as the reminders above: the preference is saved,
      // and the dashboard re-schedules on its next load.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              child: const GradientHeader(
                icon: Icons.notifications_active_rounded,
                title: 'Study reminders',
                subtitle:
                    'Choose what Learnova AI is allowed to remind you about.',
                accent: _accent,
              ),
            ),
            const SizedBox(height: 20),

            // ----- Master switch -----
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _card(
                ValueListenableBuilder<bool>(
                  valueListenable:
                      NotificationService.instance.notificationsEnabled,
                  builder: (context, enabled, _) => SwitchListTile(
                    value: enabled,
                    onChanged: (value) async {
                      NotificationService.instance.notificationsEnabled.value =
                          value;
                      if (value) {
                        await _apply();
                      } else {
                        await NotificationService.instance.cancelAll();
                      }
                    },
                    activeTrackColor: _accent.end,
                    secondary: AccentIcon(
                      icon: enabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      color: _accent.end,
                      size: 38,
                    ),
                    title: _title('All notifications'),
                    subtitle: _subtitle(
                      enabled
                          ? 'Learnova AI can send you reminders'
                          : 'All reminders are silenced',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _sectionTitle('WHAT TO BE REMINDED ABOUT'),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: ValueListenableBuilder<bool>(
                valueListenable:
                    NotificationService.instance.notificationsEnabled,
                builder: (context, masterOn, _) {
                  // The categories are meaningless while everything is off, so
                  // they dim and stop responding rather than pretending to work.
                  return AnimatedOpacity(
                    opacity: masterOn ? 1.0 : 0.45,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !masterOn,
                      child: _card(
                        Column(
                          children: [
                            _categoryTile(
                              icon: Icons.schedule_rounded,
                              title: 'Classes & study sessions',
                              subtitle: 'Timetable classes and planned study',
                              value: _study,
                              onChanged: (v) async {
                                setState(() => _study = v);
                                await _prefs.setNotifyStudySessions(v);
                                await _apply();
                              },
                            ),
                            _divider(),
                            _categoryTile(
                              icon: Icons.assignment_rounded,
                              title: 'Assignment reminders',
                              subtitle: 'Before and on the due date',
                              value: _assignments,
                              onChanged: (v) async {
                                setState(() => _assignments = v);
                                await _prefs.setNotifyAssignments(v);
                                await _apply();
                              },
                            ),
                            _divider(),
                            _categoryTile(
                              icon: Icons.school_rounded,
                              title: 'Exam reminders',
                              subtitle: 'Before and on the exam date',
                              value: _exams,
                              onChanged: (v) async {
                                setState(() => _exams = v);
                                await _prefs.setNotifyExams(v);
                                await _apply();
                              },
                            ),
                            _divider(),
                            _categoryTile(
                              icon: Icons.auto_awesome_rounded,
                              title: 'AI study suggestions',
                              subtitle: 'One tip a day from your own progress',
                              value: _suggestions,
                              onChanged: (v) async {
                                setState(() => _suggestions = v);
                                await _prefs.setNotifyAiSuggestions(v);
                                setState(() => _applying = true);
                                await _applySuggestion();
                                if (mounted) {
                                  setState(() => _applying = false);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_applying) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent.end,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Updating your reminders…',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.subText(context),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.subText(context),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Reminders are scheduled on this device from the study '
                      'reminders you create, and the daily suggestion is drawn '
                      'from your own progress. Turning a category off cancels '
                      'those alarms straight away.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.subText(context),
                      ),
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

  Widget _categoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: _accent.end,
      secondary: AccentIcon(icon: icon, color: _accent.end, size: 38),
      title: _title(title),
      subtitle: _subtitle(subtitle),
    );
  }

  Widget _card(Widget child) => GlassCard(
    blur: 0,
    elevated: true,
    borderRadius: BorderRadius.circular(20),
    child: Material(color: Colors.transparent, child: child),
  );

  Widget _sectionTitle(String text) => Padding(
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

  Widget _title(String text) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.text(context),
    ),
  );

  Widget _subtitle(String text) => Text(
    text,
    style: TextStyle(fontSize: 12, color: AppColors.subText(context)),
  );

  Widget _divider() => Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: AppColors.isDark(context)
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05),
  );
}
