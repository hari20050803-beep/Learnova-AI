import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/gemini_service.dart';
import '../services/note_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';

/// ---------------------------------------------------------------------------
/// NOTE EDITOR (create / view / edit one note)
/// Title + category + content, plus "Summarize with AI" which uses the
/// existing Gemini service on the note text.
/// Returns true via Navigator.pop when the notes list should reload.
/// ---------------------------------------------------------------------------
class NoteEditorScreen extends StatefulWidget {
  final Note? existing;

  const NoteEditorScreen({super.key, this.existing});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _category = kNoteCategories.first;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _contentController.text = existing.content;
      _category = kNoteCategories.contains(existing.category)
          ? existing.category
          : kNoteCategories.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();

    if (title.isEmpty) {
      _showMessage('Please enter a title.');
      return;
    }
    if (content.isEmpty) {
      _showMessage('Please write something in the note.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await NoteService.instance.updateNote(
          widget.existing!.copyWith(
            title: title,
            content: content,
            category: _category,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        final now = DateTime.now();
        await NoteService.instance.addNote(
          Note(
            id: '',
            title: title,
            content: content,
            category: _category,
            isFavorite: false,
            isPinned: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on NoteException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text('"${existing.title}" will be permanently deleted.'),
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
      await NoteService.instance.deleteNote(existing);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on NoteException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  /// Summarizes the current note text with Gemini and offers to append it.
  Future<void> _summarize() async {
    final String content = _contentController.text.trim();
    if (content.length < 40) {
      _showMessage('Write a bit more before summarizing.');
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.indigo),
            SizedBox(width: 20),
            Expanded(child: Text('Summarizing with AI...')),
          ],
        ),
      ),
    );

    try {
      final String summary = await GeminiService.instance.summarizeNotes(
        content,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      final bool? append = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('AI Summary'),
          content: SingleChildScrollView(child: SelectableText(summary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Append to note'),
            ),
          ],
        ),
      );
      if (append == true) {
        setState(() {
          _contentController.text =
              '${_contentController.text.trimRight()}\n\nSummary:\n$summary';
        });
      }
    } on GeminiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Note' : 'New Note'),
        actions: [
          IconButton(
            tooltip: 'Summarize with AI',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: _summarize,
          ),
          if (_isEdit)
            IconButton(
              tooltip: 'Delete note',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Note title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 70),
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final c in kNoteCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (value) => setState(
                    () => _category = value ?? kNoteCategories.first,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 140),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow(context),
                    border: AppColors.cardBorder(context),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _contentController,
                    maxLines: 12,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Write your note here...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 210),
                child: GradientButton(
                  text: _isEdit ? 'Save Changes' : 'Save Note',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
