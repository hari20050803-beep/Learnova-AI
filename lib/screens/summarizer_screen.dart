import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../models/summary_entry.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_date.dart';
import '../widgets/accent_icon.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_header.dart';

/// This module's accent, so the icons and spinner match its header instead of
/// falling back to the generic brand indigo.
const Color _accentColor = Color(0xFFEC4899); // ModuleAccent.summarizer.end

/// ---------------------------------------------------------------------------
/// AI NOTES SUMMARIZER (powered by Gemini)
/// Paste long study notes, get a short summary back. Every summary is
/// saved in Firestore (users/{uid}/summaries) and shown below.
/// ---------------------------------------------------------------------------
class SummarizerScreen extends StatefulWidget {
  const SummarizerScreen({super.key});

  @override
  State<SummarizerScreen> createState() => _SummarizerScreenState();
}

class _SummarizerScreenState extends State<SummarizerScreen> {
  final TextEditingController _notesController = TextEditingController();

  String? _summary;
  bool _isLoading = false;

  /// Saved summaries from Firestore (newest first).
  List<SummaryEntry> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// The summary split into non-empty lines (each shown as a fading point).
  List<String> get _summaryPoints => (_summary ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Loads saved summaries when the screen opens.
  Future<void> _loadHistory() async {
    try {
      final saved = await HistoryService.instance.loadSummaries();
      if (!mounted) return;
      setState(() => _history = saved);
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _summarize() async {
    final String notes = _notesController.text.trim();

    if (notes.isEmpty) {
      _showError('Please paste some notes to summarize.');
      return;
    }
    if (notes.length < 40) {
      _showError('Notes are too short to summarize. Add more text.');
      return;
    }

    setState(() {
      _isLoading = true;
      _summary = null;
    });

    try {
      // Real Gemini call.
      final String result = await GeminiService.instance.summarizeNotes(notes);

      if (!mounted) return;
      setState(() => _summary = result);

      // Save to Firestore and show it in the history list.
      try {
        final entry = await HistoryService.instance.saveSummary(
          notes: notes,
          summary: result,
        );
        if (!mounted) return;
        setState(() => _history.insert(0, entry));
      } on HistoryException catch (e) {
        if (mounted) _showError(e.message);
      }
    } on GeminiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Asks the user, then deletes one saved summary.
  Future<void> _deleteEntry(SummaryEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this summary?'),
        content: const Text('This cannot be undone.'),
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
      await HistoryService.instance.deleteSummary(entry.id);
      if (!mounted) return;
      setState(() => _history.removeWhere((e) => e.id == entry.id));
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  /// Shows the full saved summary in a dialog.
  void _showEntry(SummaryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Summary'),
        content: SingleChildScrollView(child: SelectableText(entry.summary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Notes Summarizer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ----- Brand hero header -----
              FadeSlideIn(
                child: GradientHeader(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Summarize your notes',
                  subtitle:
                      'Paste long notes and Gemini returns short revision points.',
                  accent: ModuleAccent.summarizer,
                  heroTag: moduleHeroTag(FeatureType.summarizer),
                ),
              ),
              const SizedBox(height: 20),

              // ----- Notes input card -----
              Container(
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
                    TextField(
                      controller: _notesController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText:
                            'Paste your long study notes here and Gemini '
                            'will turn them into short revision points...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      text: 'Summarize Notes',
                      isLoading: _isLoading,
                      onPressed: _summarize,
                    ),
                  ],
                ),
              ),

              // ----- Latest summary result -----
              if (_summary != null) ...[
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow(context),
                    border: AppColors.cardBorder(context),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AccentIcon(
                            icon: Icons.summarize_rounded,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 11),
                          Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Each summary point fades + slides in, one after another.
                      for (final (i, point) in _summaryPoints.indexed)
                        FadeSlideIn(
                          delay: Duration(milliseconds: 90 * i),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: SelectableText(
                              point,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.5,
                                color: AppColors.text(context),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // ----- Saved summaries from Firestore -----
              if (_isLoadingHistory) ...[
                const SizedBox(height: 24),
                const Center(
                  child: CircularProgressIndicator(color: _accentColor),
                ),
              ] else if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Previous Summaries',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in _history)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.cardShadow(context),
                    ),
                    // ListTiles need their own Material surface for the
                    // background color (avoids a Flutter debug warning).
                    child: Material(
                      color: AppColors.card(context),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: AppColors.isDark(context)
                            ? BorderSide(
                                color: Colors.white.withValues(alpha: 0.06),
                              )
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        onTap: () => _showEntry(entry),
                        title: Text(
                          entry.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.text(context),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            formatDateTime(entry.createdAt),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.subText(context),
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete summary',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                          ),
                          onPressed: () => _deleteEntry(entry),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
