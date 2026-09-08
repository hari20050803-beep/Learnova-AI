import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/feature.dart';
import '../models/study_reminder.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/animations.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_button.dart';
import 'reminder_form_screen.dart';

/// ---------------------------------------------------------------------------
/// STUDY REMINDERS
/// Tabs: Timetable / Assignment-Exam / Study Session / Upcoming / Completed.
/// Reminders are saved at users/{uid}/study_reminders and get local
/// notifications. Files (screenshot/PDF) can be read by Gemini and turned
/// into a pre-filled reminder form.
/// ---------------------------------------------------------------------------
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  List<StudyReminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Ask for notification permission the first time this module opens.
    NotificationService.instance.requestPermissions();
    _load();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _load() async {
    try {
      final reminders = await ReminderService.instance.loadReminders();
      if (!mounted) return;
      setState(() => _reminders = reminders);
    } on ReminderException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -----------------------------------------------------------------------
  // TAB CONTENTS
  // -----------------------------------------------------------------------

  List<StudyReminder> get _timetable =>
      _reminders.where((r) => r.kind == 'timetable' && !r.isCompleted).toList();

  List<StudyReminder> get _assignments => _reminders
      .where(
        (r) => (r.kind == 'assignment' || r.kind == 'exam') && !r.isCompleted,
      )
      .toList();

  List<StudyReminder> get _studySessions =>
      _reminders.where((r) => r.kind == 'study' && !r.isCompleted).toList();

  List<StudyReminder> get _upcoming {
    final now = DateTime.now();
    final list = _reminders.where((r) {
      if (r.isCompleted) return false;
      final when = r.nextOccurrence();
      return when != null && when.isAfter(now);
    }).toList();
    list.sort((a, b) => a.nextOccurrence()!.compareTo(b.nextOccurrence()!));
    return list;
  }

  List<StudyReminder> get _completed =>
      _reminders.where((r) => r.isCompleted).toList();

  // -----------------------------------------------------------------------
  // ACTIONS
  // -----------------------------------------------------------------------

  /// "Add Reminder" button: choose which kind to create.
  void _chooseKindToAdd() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final option in const [
              (
                'timetable',
                Icons.calendar_view_week_rounded,
                'Timetable Class',
              ),
              ('assignment', Icons.assignment_rounded, 'Assignment / Exam'),
              ('study', Icons.menu_book_rounded, 'Study Session'),
            ])
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: ModuleAccent.reminders.gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(option.$2, color: Colors.white, size: 20),
                ),
                title: Text(
                  option.$3,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openForm(option.$1);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(
    String formKind, {
    StudyReminder? existing,
    Map<String, dynamic>? draft,
  }) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      smoothRoute(
        ReminderFormScreen(
          formKind: formKind,
          existing: existing,
          draft: draft,
        ),
      ),
    );
    if (saved == true) {
      setState(() => _isLoading = true);
      _load();
    }
  }

  /// "Upload File" button: screenshot or PDF -> Gemini -> pre-filled form.
  void _chooseFileToUpload() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: ModuleAccent.reminders.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                'Screenshot / Image',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: ModuleAccent.reminders.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                'PDF Document',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPdf();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final String mime = file.mimeType ?? 'image/jpeg';
      await _extractFromFile(bytes, mime);
    } catch (_) {
      _showError('Could not open that image.');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _extractFromFile(bytes, 'application/pdf');
    } catch (_) {
      _showError('Could not open that PDF.');
    }
  }

  /// Sends the file to Gemini and opens the editable confirmation form.
  Future<void> _extractFromFile(List<int> bytes, String mimeType) async {
    if (bytes.length > 15 * 1024 * 1024) {
      _showError('File is too large (max 15 MB).');
      return;
    }

    // Loading dialog while Gemini reads the file.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.indigo),
            SizedBox(width: 20),
            Expanded(child: Text('Reading your file with AI...')),
          ],
        ),
      ),
    );

    try {
      final draft = await GeminiService.instance.extractReminderFromFile(
        bytes: Uint8List.fromList(bytes),
        mimeType: mimeType,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog

      // Open the editable confirmation form, pre-filled by the AI.
      final String kind = (draft['kind'] ?? 'study') as String;
      final String formKind = switch (kind) {
        'timetable' => 'timetable',
        'assignment' || 'exam' => 'assignment',
        _ => 'study',
      };
      _openForm(formKind, draft: draft);
    } on GeminiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      _showError(e.message);
    }
  }

  Future<void> _toggleCompleted(StudyReminder reminder) async {
    final bool newValue = !reminder.isCompleted;
    try {
      await ReminderService.instance.setCompleted(reminder, newValue);
      final updated = reminder.copyWith(isCompleted: newValue);
      if (newValue) {
        // Completed: stop its notifications.
        await NotificationService.instance.cancelForReminder(updated);
      } else {
        // Active again: schedule them again.
        await NotificationService.instance.scheduleForReminder(updated);
      }
      if (!mounted) return;
      setState(() {
        _reminders = _reminders
            .map((r) => r.id == reminder.id ? updated : r)
            .toList();
      });
    } on ReminderException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _delete(StudyReminder reminder) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this reminder?'),
        content: Text('"${reminder.title}" will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ReminderService.instance.deleteReminder(reminder);
      // Also remove its scheduled notifications.
      await NotificationService.instance.cancelForReminder(reminder);
      if (!mounted) return;
      setState(() => _reminders.removeWhere((r) => r.id == reminder.id));
    } on ReminderException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  void _edit(StudyReminder reminder) {
    final String formKind = switch (reminder.kind) {
      'timetable' => 'timetable',
      'assignment' || 'exam' => 'assignment',
      _ => 'study',
    };
    _openForm(formKind, existing: reminder);
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Reminders'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Timetable'),
              Tab(text: 'Assignment / Exam'),
              Tab(text: 'Study Session'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.indigo),
                )
              : TabBarView(
                  children: [
                    _list(
                      _timetable,
                      icon: Icons.schedule_rounded,
                      title: 'No classes yet',
                      message: 'Add your timetable to see it here.',
                    ),
                    _list(
                      _assignments,
                      icon: Icons.assignment_rounded,
                      title: 'Nothing due',
                      message:
                          'No assignments or exams yet — stay ahead and '
                          'add one.',
                    ),
                    _list(
                      _studySessions,
                      icon: Icons.menu_book_rounded,
                      title: 'No sessions planned',
                      message: 'Schedule a study session to see it here.',
                    ),
                    _list(
                      _upcoming,
                      icon: Icons.event_available_rounded,
                      title: 'Nothing upcoming',
                      message: 'Enjoy your day!',
                    ),
                    _list(
                      _completed,
                      icon: Icons.check_circle_rounded,
                      title: 'Nothing completed yet',
                      message: 'Finished reminders will appear here.',
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: GradientButton(
                    text: '+ Add Reminder',
                    onPressed: _chooseKindToAdd,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    text: 'Upload File',
                    onPressed: _chooseFileToUpload,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(
    List<StudyReminder> reminders, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    if (reminders.isEmpty) {
      return EmptyState(
        icon: icon,
        title: title,
        message: message,
        accent: ModuleAccent.reminders.end,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reminders.length,
      itemBuilder: (context, index) => FadeSlideIn(
        delay: Duration(milliseconds: 30 * (index.clamp(0, 6))),
        child: _reminderCard(reminders[index]),
      ),
    );
  }

  IconData _iconFor(StudyReminder r) {
    switch (r.kind) {
      case 'timetable':
        return Icons.calendar_view_week_rounded;
      case 'assignment':
        return Icons.assignment_rounded;
      case 'exam':
        return Icons.school_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  String _timeOf(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// One line describing when this reminder happens.
  String _scheduleText(StudyReminder r) {
    final start = r.startAt;
    if (start == null) return '';

    if (r.kind == 'timetable') {
      final String day = _weekdays[(r.dayOfWeek ?? start.weekday) - 1];
      String text = '$day • ${_timeOf(start)}';
      if (r.endAt != null) text += ' - ${_timeOf(r.endAt!)}';
      if (r.location != null) text += ' • ${r.location}';
      if (r.repeat == 'weekly') text += ' • Weekly';
      return text;
    }
    if (r.kind == 'study') {
      String text =
          '${start.day}/${start.month}/${start.year} • '
          '${_timeOf(start)}';
      if (r.endAt != null) text += ' - ${_timeOf(r.endAt!)}';
      if (r.repeat != 'none') {
        text += r.repeat == 'daily' ? ' • Daily' : ' • Weekly';
      }
      return text;
    }
    return 'Due ${start.day}/${start.month}/${start.year} • ${_timeOf(start)}';
  }

  Widget _reminderCard(StudyReminder reminder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: ModuleAccent.reminders.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(reminder), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _edit(reminder),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: AppColors.text(context),
                      decoration: reminder.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${reminder.subject} • ${_scheduleText(reminder)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.subText(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: reminder.isCompleted ? 'Mark as not done' : 'Mark as done',
            icon: Icon(
              reminder.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
              color: reminder.isCompleted
                  ? Colors.green.shade600
                  : AppColors.subText(context),
            ),
            onPressed: () => _toggleCompleted(reminder),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.shade400,
            ),
            onPressed: () => _delete(reminder),
          ),
        ],
      ),
    );
  }
}
