import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../models/study_roadmap.dart';
import '../services/gemini_service.dart';
import '../services/roadmap_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_header.dart';
import 'roadmap_detail_screen.dart';

/// This module's accent, so the chips, icons and spinner match its header
/// instead of falling back to the generic brand indigo.
const ModuleAccent _accent = ModuleAccent.roadmap;

/// ---------------------------------------------------------------------------
/// AI STUDY ROADMAP (home)
/// Enter a subject, exam date, skill level and study hours, then let Gemini
/// build a personalized plan. Saved at users/{uid}/study_roadmaps and listed
/// under "My Roadmaps" (open / delete).
/// ---------------------------------------------------------------------------
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final TextEditingController _subjectController = TextEditingController();

  DateTime? _examDate;
  String _skillLevel = kSkillLevels.first;
  int _studyHours = 2;

  bool _isGenerating = false;
  bool _isLoading = true;

  List<StudyRoadmap> _roadmaps = [];

  @override
  void initState() {
    super.initState();
    _loadRoadmaps();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
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

  String _dateText(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _loadRoadmaps() async {
    try {
      final roadmaps = await RoadmapService.instance.loadRoadmaps();
      if (mounted) setState(() => _roadmaps = roadmaps);
    } on RoadmapException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickExamDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  Future<void> _generate() async {
    final String subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      _showMessage('Please enter a subject.');
      return;
    }
    final DateTime? examDate = _examDate;
    if (examDate == null) {
      _showMessage('Please pick your exam date.');
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final String plan = await GeminiService.instance.generateRoadmap(
        subject: subject,
        examDate: examDate,
        studyHours: _studyHours,
        skillLevel: _skillLevel,
      );
      final roadmap = StudyRoadmap(
        id: '',
        subject: subject,
        examDate: examDate,
        studyHours: _studyHours,
        skillLevel: _skillLevel,
        roadmap: plan,
        createdAt: DateTime.now(),
      );
      final saved = await RoadmapService.instance.saveRoadmap(roadmap);
      if (!mounted) return;
      setState(() => _roadmaps = [saved, ..._roadmaps]);
      _showMessage('Your study roadmap is ready!', isError: false);
      _openRoadmap(saved);
    } on GeminiException catch (e) {
      if (mounted) _showMessage(e.message);
    } on RoadmapException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _openRoadmap(StudyRoadmap roadmap) {
    Navigator.of(
      context,
    ).push(smoothRoute(RoadmapDetailScreen(roadmap: roadmap)));
  }

  Future<void> _deleteRoadmap(StudyRoadmap roadmap) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this roadmap?'),
        content: Text('The roadmap for "${roadmap.subject}" will be deleted.'),
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
      await RoadmapService.instance.deleteRoadmap(roadmap.id);
      if (!mounted) return;
      setState(() => _roadmaps.removeWhere((r) => r.id == roadmap.id));
    } on RoadmapException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Study Roadmap')),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _accent.end))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FadeSlideIn(
                    child: GradientHeader(
                      icon: Icons.map_rounded,
                      title: 'Plan your study',
                      subtitle:
                          'Get a personalized day-by-day plan for your exam.',
                      accent: ModuleAccent.roadmap,
                      heroTag: moduleHeroTag(FeatureType.roadmap),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _formCard(),
                  const SizedBox(height: 24),
                  if (_roadmaps.isNotEmpty) _myRoadmapsSection(),
                ],
              ),
      ),
    );
  }

  Widget _formCard() {
    return FadeSlideIn(
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
            _label('Subject'),
            TextField(
              controller: _subjectController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Operating Systems, Organic Chemistry',
                prefixIcon: Icon(Icons.book_outlined),
              ),
            ),
            const SizedBox(height: 16),

            _label('Exam date'),
            _dateTile(),
            const SizedBox(height: 16),

            _label('Current skill level'),
            Wrap(
              spacing: 8,
              children: [
                for (final level in kSkillLevels)
                  ChoiceChip(
                    label: Text(level),
                    selected: _skillLevel == level,
                    selectedColor: _accent.end,
                    labelStyle: TextStyle(
                      color: _skillLevel == level
                          ? Colors.white
                          : AppColors.text(context),
                      fontSize: 12.5,
                    ),
                    onSelected: (_) => setState(() => _skillLevel = level),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            _label('Study hours per day'),
            Wrap(
              spacing: 8,
              children: [
                for (final h in [1, 2, 3, 4, 5, 6])
                  ChoiceChip(
                    label: Text('$h'),
                    selected: _studyHours == h,
                    selectedColor: _accent.end,
                    labelStyle: TextStyle(
                      color: _studyHours == h
                          ? Colors.white
                          : AppColors.text(context),
                    ),
                    onSelected: (_) => setState(() => _studyHours = h),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            GradientButton(
              text: 'Generate Roadmap',
              isLoading: _isGenerating,
              onPressed: _generate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile() {
    final bool hasDate = _examDate != null;
    return InkWell(
      onTap: _pickExamDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.isDark(context)
              ? const Color(0xFF222A4D)
              : const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              color: AppColors.readable(context, _accent.end),
            ),
            const SizedBox(width: 12),
            Text(
              hasDate ? _dateText(_examDate!) : 'Select exam date',
              style: TextStyle(
                fontSize: 15,
                color: hasDate
                    ? AppColors.text(context)
                    : AppColors.subText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _myRoadmapsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Roadmaps',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_roadmaps.length})',
              style: TextStyle(color: AppColors.subText(context)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (index, roadmap) in _roadmaps.indexed) ...[
          FadeSlideIn(
            delay: Duration(milliseconds: 30 * (index.clamp(0, 6))),
            child: _roadmapTile(roadmap),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _roadmapTile(StudyRoadmap roadmap) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openRoadmap(roadmap),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: _accent.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.map_rounded,
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
                      roadmap.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Exam ${_dateText(roadmap.examDate)}  •  '
                      '${roadmap.skillLevel}  •  ${roadmap.studyHours} hrs/day',
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
              IconButton(
                tooltip: 'Delete roadmap',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade400,
                ),
                onPressed: () => _deleteRoadmap(roadmap),
              ),
            ],
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
}
