import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feature.dart';
import '../models/gpa_record.dart';
import '../services/gpa_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_date.dart';
import '../widgets/animations.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_button.dart';

/// ---------------------------------------------------------------------------
/// GPA CALCULATOR
/// Tab 1 (Calculator): add subjects, see live GPA, save the semester.
/// Tab 2 (History): past saved GPA records, with delete.
/// Records are saved user-wise at users/{uid}/gpa_records.
/// ---------------------------------------------------------------------------
class GpaScreen extends StatefulWidget {
  const GpaScreen({super.key});

  @override
  State<GpaScreen> createState() => _GpaScreenState();
}

class _GpaScreenState extends State<GpaScreen> {
  final TextEditingController _semesterController = TextEditingController();

  /// Subjects in the calculator right now.
  final List<GpaSubject> _subjects = [];

  /// Saved records from Firestore (newest first).
  List<GpaRecord> _history = [];
  bool _isLoadingHistory = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _semesterController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // CALCULATIONS
  // -----------------------------------------------------------------------

  double get _totalCredits => _subjects.fold(0.0, (sum, s) => sum + s.credit);

  double get _gpa {
    final double credits = _totalCredits;
    if (credits == 0) return 0;
    final double weighted = _subjects.fold(
      0.0,
      (sum, s) => sum + s.credit * s.gradePoint,
    );
    return weighted / credits;
  }

  /// Shows a number without a trailing ".0" (e.g. 3 instead of 3.0).
  String _fmtCredit(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // SUBJECT ACTIONS
  // -----------------------------------------------------------------------

  /// Add a new subject or edit an existing one (bottom sheet form).
  /// The sheet owns its own controllers and returns the finished subject,
  /// so we only touch our state AFTER the sheet has fully closed.
  Future<void> _showSubjectSheet({GpaSubject? existing, int? index}) async {
    final GpaSubject? result = await showModalBottomSheet<GpaSubject>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SubjectSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _subjects.add(result);
      } else {
        _subjects[index] = result;
      }
    });
  }

  void _deleteSubject(int index) {
    setState(() => _subjects.removeAt(index));
  }

  Future<void> _clearAll() async {
    if (_subjects.isEmpty) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all subjects?'),
        content: const Text('This removes every subject from the calculator.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) setState(() => _subjects.clear());
  }

  // -----------------------------------------------------------------------
  // RECORD ACTIONS
  // -----------------------------------------------------------------------

  Future<void> _loadHistory() async {
    try {
      final records = await GpaService.instance.loadRecords();
      if (!mounted) return;
      setState(() => _history = records);
    } on GpaException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveRecord() async {
    if (_subjects.isEmpty) {
      _showMessage('Add at least one subject first.');
      return;
    }
    final String semester = _semesterController.text.trim().isEmpty
        ? 'Semester ${_history.length + 1}'
        : _semesterController.text.trim();

    setState(() => _isSaving = true);
    try {
      final record = GpaRecord(
        id: '',
        semesterName: semester,
        subjects: List.of(_subjects),
        totalCredits: _totalCredits,
        gpa: _gpa,
        createdAt: DateTime.now(),
      );
      final saved = await GpaService.instance.saveRecord(record);
      if (!mounted) return;
      setState(() {
        _history.insert(0, saved);
        _subjects.clear();
        _semesterController.clear();
      });
      _showMessage('GPA record saved!', isError: false);
    } on GpaException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteRecord(GpaRecord record) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text('"${record.semesterName}" will be deleted.'),
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
      await GpaService.instance.deleteRecord(record.id);
      if (!mounted) return;
      setState(() => _history.removeWhere((r) => r.id == record.id));
    } on GpaException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('GPA Calculator'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Calculator'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [_buildCalculatorTab(), _buildHistoryTab()],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----- Result card (live GPA) -----
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: ModuleAccent.gpa.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Semester GPA',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _gpa.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subjects.isEmpty
                      ? 'Add subjects to see your GPA'
                      : gpaStatusMessage(_gpa),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Total credits: ${_fmtCredit(_totalCredits)}  •  '
                    '${_subjects.length} subject'
                    '${_subjects.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ----- Semester name -----
          TextField(
            controller: _semesterController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Semester name (e.g. Semester 1)',
              prefixIcon: Icon(Icons.event_note_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // ----- Subject list -----
          if (_subjects.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow(context),
                border: AppColors.cardBorder(context),
              ),
              child: const EmptyState(
                icon: Icons.calculate_rounded,
                title: 'No subjects yet',
                message: 'Tap "Add Subject" to begin.',
                accent: Color(0xFF059669), // ModuleAccent.gpa.end
              ),
            )
          else
            for (int i = 0; i < _subjects.length; i++)
              _subjectCard(_subjects[i], i),

          const SizedBox(height: 16),

          // ----- Add subject -----
          GradientButton(
            text: '+ Add Subject',
            onPressed: () => _showSubjectSheet(),
          ),
          const SizedBox(height: 12),

          // ----- Save + Clear all -----
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  text: 'Save Record',
                  isLoading: _isSaving,
                  onPressed: _saveRecord,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearAll,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subjectCard(GpaSubject subject, int index) {
    return Container(
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
          // Grade badge.
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ModuleAccent.gpa.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subject.grade,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _showSubjectSheet(existing: subject, index: index),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_fmtCredit(subject.credit)} credits  •  '
                    'grade point ${subject.gradePoint.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.subText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete subject',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.shade400,
            ),
            onPressed: () => _deleteSubject(index),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo),
      );
    }
    if (_history.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No saved records',
        message: 'Calculate a GPA and save it to see it here.',
        accent: Color(0xFF059669), // ModuleAccent.gpa.end
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final record = _history[index];
        return FadeSlideIn(
          delay: Duration(milliseconds: 30 * (index.clamp(0, 6))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow(context),
              border: AppColors.cardBorder(context),
            ),
            child: Row(
              children: [
                // GPA badge.
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: ModuleAccent.gpa.gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    record.gpa.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.semesterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_fmtCredit(record.totalCredits)} credits  •  '
                        '${record.subjects.length} subjects',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subText(context),
                        ),
                      ),
                      Text(
                        formatDateTime(record.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.subText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete record',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () => _deleteRecord(record),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// SUBJECT SHEET (add / edit one subject)
/// A self-contained bottom sheet that owns its controllers and returns the
/// finished [GpaSubject] via Navigator.pop. Keeping it separate avoids
/// lifecycle problems (disposing controllers / setState during dismiss).
/// ---------------------------------------------------------------------------
class _SubjectSheet extends StatefulWidget {
  final GpaSubject? existing;

  const _SubjectSheet({this.existing});

  @override
  State<_SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends State<_SubjectSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _creditController;
  late String _grade;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _creditController = TextEditingController(
      text: widget.existing == null ? '' : _fmtCredit(widget.existing!.credit),
    );
    _grade = widget.existing?.grade ?? 'A';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  String _fmtCredit(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final double? credit = double.tryParse(_creditController.text.trim());
    if (name.isEmpty) {
      _showError('Please enter a subject name.');
      return;
    }
    if (credit == null || credit <= 0) {
      _showError('Please enter a valid credit value.');
      return;
    }
    Navigator.of(context).pop(
      GpaSubject(
        name: name,
        credit: credit,
        grade: _grade,
        gradePoint: kGradePoints[_grade]!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        // Scrollable so the sheet never overflows when the keyboard is up.
        child: SingleChildScrollView(
          child: FadeSlideIn(
            slideFraction: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.subText(context).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEdit ? 'Edit Subject' : 'Add Subject',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Subject / Module name',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _creditController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Credit value (e.g. 3)',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                // Grade dropdown (auto-fills the grade point).
                DropdownButtonFormField<String>(
                  initialValue: _grade,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.grade_outlined),
                  ),
                  items: [
                    for (final g in kGradeOrder)
                      DropdownMenuItem(
                        value: g,
                        child: Text(
                          '$g   (${kGradePoints[g]!.toStringAsFixed(1)})',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _grade = value ?? 'A'),
                ),
                const SizedBox(height: 12),
                // Live grade-point preview.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withValues(
                      alpha: AppColors.isDark(context) ? 0.20 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Grade point: ${kGradePoints[_grade]!.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: AppColors.isDark(context)
                          ? const Color(0xFFB9B4FF)
                          : AppColors.indigo,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  text: isEdit ? 'Save Changes' : 'Add Subject',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
