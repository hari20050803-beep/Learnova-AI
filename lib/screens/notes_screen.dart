import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_date.dart';
import '../utils/smooth_route.dart';
import '../widgets/animations.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_button.dart';
import 'note_editor_screen.dart';

/// ---------------------------------------------------------------------------
/// NOTES MANAGEMENT
/// Create / view / edit / delete notes, search, filter by category,
/// favorite and pin. Pinned notes appear first. Notes are saved at
/// users/{uid}/notes (Firestore only — no Storage).
/// ---------------------------------------------------------------------------
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Note> _notes = [];
  bool _isLoading = true;
  String _search = '';
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
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
      final notes = await NoteService.instance.loadNotes();
      if (!mounted) return;
      setState(() => _notes = notes);
    } on NoteException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Notes after search + category filter (pinned-first order is kept).
  List<Note> get _visible {
    final String q = _search.trim().toLowerCase();
    return _notes.where((n) {
      final matchesCategory =
          _categoryFilter == 'All' || n.category == _categoryFilter;
      final matchesSearch =
          q.isEmpty ||
          n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.category.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // -----------------------------------------------------------------------
  // ACTIONS
  // -----------------------------------------------------------------------

  Future<void> _openEditor({Note? existing}) async {
    final bool? changed = await Navigator.of(
      context,
    ).push<bool>(smoothRoute(NoteEditorScreen(existing: existing)));
    if (changed == true) {
      setState(() => _isLoading = true);
      _load();
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    final bool newValue = !note.isFavorite;
    try {
      await NoteService.instance.setFavorite(note, newValue);
      if (!mounted) return;
      setState(() {
        _notes = _notes
            .map((n) => n.id == note.id ? n.copyWith(isFavorite: newValue) : n)
            .toList();
      });
    } on NoteException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  Future<void> _togglePin(Note note) async {
    final bool newValue = !note.isPinned;
    try {
      await NoteService.instance.setPinned(note, newValue);
      if (!mounted) return;
      setState(() {
        _notes = _notes
            .map((n) => n.id == note.id ? n.copyWith(isPinned: newValue) : n)
            .toList();
        // Re-apply pinned-first ordering.
        _notes.sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
      });
    } on NoteException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(title: const Text('Notes Management')),
      body: SafeArea(
        child: Column(
          children: [
            // ----- Search -----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
              ),
            ),

            // ----- Category filter chips -----
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in ['All', ...kNoteCategories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _categoryFilter == c,
                        selectedColor: ModuleAccent.notes.start,
                        labelStyle: TextStyle(
                          color: _categoryFilter == c
                              ? Colors.white
                              : AppColors.text(context),
                          fontSize: 12.5,
                        ),
                        onSelected: (_) => setState(() => _categoryFilter = c),
                      ),
                    ),
                ],
              ),
            ),

            // ----- List -----
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ModuleAccent.notes.end,
                      ),
                    )
                  : visible.isEmpty
                  ? (_notes.isEmpty
                        ? EmptyState(
                            icon: Icons.note_alt_rounded,
                            title: 'No notes yet',
                            message: 'Tap "New Note" to start writing!',
                            accent: ModuleAccent.notes.end,
                          )
                        : EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            message: 'No notes match your search.',
                            accent: ModuleAccent.notes.end,
                          ))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => FadeSlideIn(
                        delay: Duration(milliseconds: 30 * (index.clamp(0, 6))),
                        child: _noteCard(visible[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GradientButton(
            text: '+ New Note',
            onPressed: () => _openEditor(),
          ),
        ),
      ),
    );
  }

  Widget _noteCard(Note note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openEditor(existing: note),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: AppColors.readable(context, AppColors.purple),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                  // Pin toggle.
                  GestureDetector(
                    onTap: () => _togglePin(note),
                    child: Icon(
                      note.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 20,
                      color: note.isPinned
                          ? AppColors.purple
                          : AppColors.subText(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Favorite toggle.
                  GestureDetector(
                    onTap: () => _toggleFavorite(note),
                    child: Icon(
                      note.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 20,
                      color: note.isFavorite
                          ? Colors.amber
                          : AppColors.subText(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.subText(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      // Notes module accent (amber).
                      color: ModuleAccent.notes.start.withValues(
                        alpha: AppColors.isDark(context) ? 0.22 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      note.category,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.isDark(context)
                            ? const Color(0xFFFBBF6B)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatDateTime(note.updatedAt),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.subText(context),
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
}
