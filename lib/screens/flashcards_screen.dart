import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../models/flashcard.dart';
import '../models/note.dart';
import '../services/flashcard_service.dart';
import '../services/gemini_service.dart';
import '../services/note_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_header.dart';
import 'flashcard_study_screen.dart';

/// This module's accent, so the chips, pills and spinner match its header
/// instead of falling back to the generic brand indigo.
const ModuleAccent _accent = ModuleAccent.flashcards;

/// ---------------------------------------------------------------------------
/// AI FLASHCARDS (home)
/// Generate flashcards from a typed topic or a saved note, choose how many,
/// then study or re-open the saved deck. Saved at users/{uid}/flashcards.
/// ---------------------------------------------------------------------------
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final TextEditingController _topicController = TextEditingController();

  /// 'topic' or 'notes'
  String _mode = 'topic';
  int _count = 10;
  Note? _selectedNote;

  bool _isGenerating = false;
  bool _isLoading = true;

  List<Flashcard> _cards = [];
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _topicController.dispose();
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

  Future<void> _loadInitial() async {
    try {
      final cards = await FlashcardService.instance.loadFlashcards();
      if (mounted) setState(() => _cards = cards);
    } on FlashcardException catch (e) {
      if (mounted) _showMessage(e.message);
    }
    try {
      // Used by the "From a note" picker.
      final notes = await NoteService.instance.loadNotes();
      if (mounted) setState(() => _notes = notes);
    } on NoteException catch (_) {
      // ignore: the picker just stays empty
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _reloadCards() async {
    try {
      final cards = await FlashcardService.instance.loadFlashcards();
      if (mounted) setState(() => _cards = cards);
    } on FlashcardException catch (_) {
      // ignore
    }
  }

  Future<void> _generate() async {
    final String content;
    final String subject;
    if (_mode == 'topic') {
      final String topic = _topicController.text.trim();
      if (topic.isEmpty) {
        _showMessage('Please enter a topic.');
        return;
      }
      content = topic;
      subject = topic;
    } else {
      final Note? note = _selectedNote;
      if (note == null) {
        _showMessage('Please pick a note.');
        return;
      }
      if (note.content.trim().length < 20) {
        _showMessage('That note is too short to make flashcards.');
        return;
      }
      content = note.content;
      subject = note.title.trim().isEmpty ? note.category : note.title;
    }

    setState(() => _isGenerating = true);
    try {
      final generated = await GeminiService.instance.generateFlashcards(
        content: content,
        count: _count,
        subject: subject,
      );
      final saved = await FlashcardService.instance.saveFlashcards(generated);
      if (!mounted) return;
      setState(() => _cards = [...saved, ..._cards]);
      _showMessage('Generated ${saved.length} flashcards!', isError: false);
      _openStudy(saved);
    } on GeminiException catch (e) {
      if (mounted) _showMessage(e.message);
    } on FlashcardException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _openStudy(List<Flashcard> cards, {int initialIndex = 0}) async {
    if (cards.isEmpty) return;
    await Navigator.of(context).push(
      smoothRoute(
        FlashcardStudyScreen(cards: cards, initialIndex: initialIndex),
      ),
    );
    // Status / favorite may have changed while studying.
    _reloadCards();
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Flashcards')),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _accent.end))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FadeSlideIn(
                    child: GradientHeader(
                      icon: Icons.style_rounded,
                      title: 'Create flashcards',
                      subtitle:
                          'Generate cards from a topic or a saved note, then study.',
                      accent: ModuleAccent.flashcards,
                      heroTag: moduleHeroTag(FeatureType.flashcards),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _generateCard(),
                  const SizedBox(height: 24),
                  if (_cards.isNotEmpty) _savedSection(),
                ],
              ),
      ),
    );
  }

  Widget _generateCard() {
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
            // ----- Source mode -----
            Row(
              children: [
                _modeChip('From a topic', 'topic'),
                const SizedBox(width: 8),
                _modeChip('From a note', 'notes'),
              ],
            ),
            const SizedBox(height: 14),
            if (_mode == 'topic')
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(
                  hintText: 'Topic, e.g. Polymorphism, Photosynthesis',
                  prefixIcon: Icon(Icons.topic_outlined),
                ),
              )
            else
              _notePicker(),
            const SizedBox(height: 16),

            // ----- Number of cards -----
            Row(
              children: [
                Text(
                  'Cards:',
                  style: TextStyle(
                    color: AppColors.subText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                for (final c in [5, 10, 15]) ...[
                  ChoiceChip(
                    label: Text('$c'),
                    selected: _count == c,
                    selectedColor: _accent.end,
                    labelStyle: TextStyle(
                      color: _count == c
                          ? Colors.white
                          : AppColors.text(context),
                    ),
                    onSelected: (_) => setState(() => _count = c),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            GradientButton(
              text: 'Generate Flashcards',
              isLoading: _isGenerating,
              onPressed: _generate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _mode == value,
      selectedColor: _accent.end,
      labelStyle: TextStyle(
        color: _mode == value ? Colors.white : AppColors.text(context),
        fontSize: 12.5,
      ),
      onSelected: (_) => setState(() => _mode = value),
    );
  }

  Widget _notePicker() {
    if (_notes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _accent.end.withValues(
            alpha: AppColors.isDark(context) ? 0.15 : 0.06,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'You have no saved notes yet. Create a note first, or use '
          '"From a topic".',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.subText(context),
            height: 1.4,
          ),
        ),
      );
    }
    return DropdownButtonFormField<Note>(
      initialValue: _selectedNote,
      isExpanded: true,
      decoration: const InputDecoration(
        hintText: 'Pick a note',
        prefixIcon: Icon(Icons.description_outlined),
      ),
      items: [
        for (final note in _notes)
          DropdownMenuItem(
            value: note,
            child: Text(
              note.title.trim().isEmpty ? '(untitled note)' : note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (note) => setState(() => _selectedNote = note),
    );
  }

  Widget _savedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Your Flashcards',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_cards.length})',
              style: TextStyle(color: AppColors.subText(context)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GradientButton(
          text: 'Study All (${_cards.length})',
          onPressed: () => _openStudy(_cards),
        ),
        const SizedBox(height: 16),
        for (final (index, card) in _cards.indexed) ...[
          FadeSlideIn(
            delay: Duration(milliseconds: 30 * (index.clamp(0, 6))),
            child: _cardTile(card, index),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _cardTile(Flashcard card, int index) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openStudy(_cards, initialIndex: index),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: _pill(
                      card.subject.trim().isEmpty ? 'Flashcard' : card.subject,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    card.difficulty,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.subText(context),
                    ),
                  ),
                  const Spacer(),
                  if (card.isFavorite)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),
                  Text(
                    card.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(card),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _accent.end.withValues(
          alpha: AppColors.isDark(context) ? 0.20 : 0.08,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.readable(context, _accent.end),
        ),
      ),
    );
  }

  Color _statusColor(Flashcard card) {
    switch (card.status) {
      case kFlashcardStatusKnown:
        return Colors.green.shade600;
      case kFlashcardStatusRevision:
        return Colors.orange.shade700;
      default:
        return AppColors.subText(context);
    }
  }
}
