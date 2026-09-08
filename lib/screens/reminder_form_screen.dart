import 'package:flutter/material.dart';

import '../models/study_reminder.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';

/// ---------------------------------------------------------------------------
/// REMINDER FORM
/// One form for all reminder kinds:
///   - formKind 'timetable'  : weekly class
///   - formKind 'assignment' : assignment OR exam (toggle inside the form)
///   - formKind 'study'      : study session
/// Also used as the editable confirmation form after AI file extraction
/// ([draft]) and for editing an existing reminder ([existing]).
/// ---------------------------------------------------------------------------
class ReminderFormScreen extends StatefulWidget {
  final String formKind;
  final StudyReminder? existing;
  final Map<String, dynamic>? draft;

  const ReminderFormScreen({
    super.key,
    required this.formKind,
    this.existing,
    this.draft,
  });

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _lecturerController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late String _kind; // actual kind: timetable / assignment / exam / study
  int _dayOfWeek = DateTime.now().weekday;
  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _repeatWeekly = true; // timetable
  String _repeat = 'none'; // study session
  late int _remindBefore;
  bool _isSaving = false;

  bool get _isTimetable => widget.formKind == 'timetable';
  bool get _isAssignment => widget.formKind == 'assignment';
  bool get _isStudy => widget.formKind == 'study';

  @override
  void initState() {
    super.initState();
    _kind = _isAssignment ? 'assignment' : widget.formKind;
    _remindBefore = _isAssignment ? 1440 : 15;

    final existing = widget.existing;
    if (existing != null) _fillFromExisting(existing);
    final draft = widget.draft;
    if (draft != null) _fillFromDraft(draft);
  }

  void _fillFromExisting(StudyReminder r) {
    _kind = r.kind;
    _titleController.text = r.title;
    _subjectController.text = r.subject;
    _lecturerController.text = r.lecturer ?? '';
    _locationController.text = r.location ?? '';
    _notesController.text = r.notes ?? '';
    _dayOfWeek = r.dayOfWeek ?? DateTime.now().weekday;
    _repeatWeekly = r.repeat == 'weekly';
    _repeat = r.repeat;
    _remindBefore = r.remindBefore;
    if (r.startAt != null) {
      _date = r.startAt;
      _startTime = TimeOfDay.fromDateTime(r.startAt!);
    }
    if (r.endAt != null) _endTime = TimeOfDay.fromDateTime(r.endAt!);
  }

  /// Pre-fills the form with what Gemini extracted from the file.
  void _fillFromDraft(Map<String, dynamic> draft) {
    String text(String key) => (draft[key] ?? '').toString();

    if (draft['kind'] == 'exam') _kind = 'exam';
    _titleController.text = text('title');
    _subjectController.text = text('subject');
    _lecturerController.text = draft['lecturer'] == null
        ? ''
        : text('lecturer');
    _locationController.text = draft['location'] == null
        ? ''
        : text('location');
    _notesController.text = draft['notes'] == null ? '' : text('notes');

    final int? day = (draft['dayOfWeek'] as num?)?.toInt();
    if (day != null && day >= 1 && day <= 7) _dayOfWeek = day;

    final DateTime? date = DateTime.tryParse(text('date'));
    if (date != null) _date = date;

    _startTime = _parseTime(text('startTime'));
    _endTime = _parseTime(text('endTime'));
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final int? h = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _lecturerController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
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

  // -----------------------------------------------------------------------
  // SAVE
  // -----------------------------------------------------------------------

  /// Next date that falls on [weekday] at [time] (for weekly classes).
  DateTime _nextWeekday(int weekday, TimeOfDay time) {
    final now = DateTime.now();
    DateTime d = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    while (d.weekday != weekday || d.isBefore(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  Future<void> _save() async {
    final String title = _isTimetable
        ? _subjectController.text.trim()
        : _titleController.text.trim();
    final String subject = _subjectController.text.trim();

    // ----- Validation -----
    if (title.isEmpty || subject.isEmpty) {
      _showError('Please fill in the required fields.');
      return;
    }
    if (!_isTimetable && _date == null) {
      _showError('Please pick a date.');
      return;
    }
    if (_startTime == null) {
      _showError(
        _isAssignment ? 'Please pick a time.' : 'Please pick a start time.',
      );
      return;
    }
    if ((_isTimetable || _isStudy) && _endTime == null) {
      _showError('Please pick an end time.');
      return;
    }

    // ----- Build the date/time fields -----
    DateTime startAt;
    DateTime? endAt;
    String repeat;
    int? dayOfWeek;

    if (_isTimetable) {
      dayOfWeek = _dayOfWeek;
      startAt = _nextWeekday(_dayOfWeek, _startTime!);
      endAt = DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        _endTime!.hour,
        _endTime!.minute,
      );
      repeat = _repeatWeekly ? 'weekly' : 'none';
    } else if (_isStudy) {
      startAt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _startTime!.hour,
        _startTime!.minute,
      );
      endAt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _endTime!.hour,
        _endTime!.minute,
      );
      repeat = _repeat;
      if (repeat == 'weekly') dayOfWeek = startAt.weekday;
    } else {
      startAt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _startTime!.hour,
        _startTime!.minute,
      );
      repeat = 'none';
    }

    final existing = widget.existing;
    final reminder = StudyReminder(
      id: existing?.id ?? '',
      kind: _kind,
      title: title,
      subject: subject,
      lecturer: _lecturerController.text.trim().isEmpty
          ? null
          : _lecturerController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      dayOfWeek: dayOfWeek,
      startAt: startAt,
      endAt: endAt,
      repeat: repeat,
      remindBefore: _remindBefore,
      isCompleted: existing?.isCompleted ?? false,
      notifId:
          existing?.notifId ??
          DateTime.now().millisecondsSinceEpoch.remainder(0x7FFFFFF),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      StudyReminder saved;
      if (existing == null) {
        saved = await ReminderService.instance.addReminder(reminder);
      } else {
        await ReminderService.instance.updateReminder(reminder);
        saved = reminder;
      }
      // Schedule (or reschedule) the local notifications.
      await NotificationService.instance.scheduleForReminder(saved);

      if (!mounted) return;
      Navigator.of(context).pop(true); // true = list must reload
    } on ReminderException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  String get _screenTitle {
    final String action = widget.existing == null ? 'Add' : 'Edit';
    if (_isTimetable) return '$action Class';
    if (_isStudy) return '$action Study Session';
    return '$action Assignment / Exam';
  }

  String _timeText(TimeOfDay? t) => t == null
      ? 'Select'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _pickCustomDays() async {
    final controller = TextEditingController();
    final int? days = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remind how many days before?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Number of days'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(int.tryParse(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (days != null && days > 0) {
      setState(() => _remindBefore = days * 1440);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: FadeSlideIn(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow(context),
                border: AppColors.cardBorder(context),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ----- Assignment / Exam type toggle -----
                  if (_isAssignment) ...[
                    _label('Type'),
                    Row(
                      children: [
                        for (final option in const [
                          ('assignment', 'Assignment'),
                          ('exam', 'Exam'),
                        ]) ...[
                          ChoiceChip(
                            label: Text(option.$2),
                            selected: _kind == option.$1,
                            selectedColor: AppColors.indigo,
                            labelStyle: TextStyle(
                              color: _kind == option.$1
                                  ? Colors.white
                                  : AppColors.text(context),
                            ),
                            onSelected: (_) =>
                                setState(() => _kind = option.$1),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Title (e.g. OS Lab Report 2)',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isStudy) ...[
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Title (e.g. Revise Unit 3)',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ----- Subject -----
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      hintText: 'Subject',
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ----- Timetable-only fields -----
                  if (_isTimetable) ...[
                    TextField(
                      controller: _lecturerController,
                      decoration: const InputDecoration(
                        hintText: 'Lecturer (optional)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Day of week'),
                    DropdownButtonFormField<int>(
                      initialValue: _dayOfWeek,
                      items: [
                        for (int d = 1; d <= 7; d++)
                          DropdownMenuItem(
                            value: d,
                            child: Text(_weekdays[d - 1]),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _dayOfWeek = value ?? 1),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.calendar_view_week_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ----- Date (assignment / exam / study) -----
                  if (!_isTimetable) ...[
                    _pickerTile(
                      icon: Icons.event_rounded,
                      label: _kind == 'exam'
                          ? 'Exam date'
                          : _isStudy
                          ? 'Date'
                          : 'Due date',
                      value: _date == null
                          ? 'Select'
                          : '${_date!.day}/${_date!.month}/${_date!.year}',
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ----- Times -----
                  Row(
                    children: [
                      Expanded(
                        child: _pickerTile(
                          icon: Icons.schedule_rounded,
                          label: _isAssignment
                              ? (_kind == 'exam' ? 'Exam time' : 'Due time')
                              : 'Start time',
                          value: _timeText(_startTime),
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      if (!_isAssignment) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.schedule_rounded,
                            label: 'End time',
                            value: _timeText(_endTime),
                            onTap: () => _pickTime(false),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ----- Location (timetable) -----
                  if (_isTimetable) ...[
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Location (optional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: _repeatWeekly,
                      onChanged: (v) => setState(() => _repeatWeekly = v),
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: AppColors.indigo,
                      title: Text(
                        'Repeat weekly',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ----- Repeat (study session) -----
                  if (_isStudy) ...[
                    _label('Repeat'),
                    Row(
                      children: [
                        for (final option in const [
                          ('none', 'None'),
                          ('daily', 'Daily'),
                          ('weekly', 'Weekly'),
                        ]) ...[
                          ChoiceChip(
                            label: Text(option.$2),
                            selected: _repeat == option.$1,
                            selectedColor: AppColors.indigo,
                            labelStyle: TextStyle(
                              color: _repeat == option.$1
                                  ? Colors.white
                                  : AppColors.text(context),
                            ),
                            onSelected: (_) =>
                                setState(() => _repeat = option.$1),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ----- Remind before -----
                  _label('Remind me before'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_isAssignment) ...[
                        for (final option in const [
                          (0, 'Same day'),
                          (1440, '1 day'),
                          (2880, '2 days'),
                          (10080, '1 week'),
                        ])
                          _remindChip(option.$1, option.$2),
                        ChoiceChip(
                          label: Text(
                            const [0, 1440, 2880, 10080].contains(_remindBefore)
                                ? 'Custom'
                                : 'Custom: ${_remindBefore ~/ 1440} days',
                          ),
                          selected: ![
                            0,
                            1440,
                            2880,
                            10080,
                          ].contains(_remindBefore),
                          selectedColor: AppColors.indigo,
                          labelStyle: TextStyle(
                            color:
                                ![0, 1440, 2880, 10080].contains(_remindBefore)
                                ? Colors.white
                                : AppColors.text(context),
                          ),
                          onSelected: (_) => _pickCustomDays(),
                        ),
                      ] else ...[
                        for (final option in const [
                          (15, '15 min'),
                          (30, '30 min'),
                          (60, '60 min'),
                        ])
                          _remindChip(option.$1, option.$2),
                      ],
                    ],
                  ),

                  // ----- Notes (assignment / exam) -----
                  if (_isAssignment) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Notes (optional)',
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  GradientButton(
                    text: widget.existing == null
                        ? 'Save Reminder'
                        : 'Update Reminder',
                    isLoading: _isSaving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: AppColors.subText(context),
        ),
      ),
    );
  }

  Widget _remindChip(int minutes, String labelText) {
    final bool selected = _remindBefore == minutes;
    return ChoiceChip(
      label: Text(labelText),
      selected: selected,
      selectedColor: AppColors.indigo,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text(context),
      ),
      onSelected: (_) => setState(() => _remindBefore = minutes),
    );
  }

  /// A tappable tile styled like the text fields (for date/time pickers).
  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.isDark(context)
              ? const Color(0xFF222A4D)
              : const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.readable(context, AppColors.indigo),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.subText(context),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
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
}
