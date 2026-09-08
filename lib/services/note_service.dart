import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/note.dart';

/// Thrown by [NoteService] with a message safe to show to the user.
class NoteException implements Exception {
  final String message;

  NoteException(this.message);

  @override
  String toString() => message;
}

/// Count + most recent note, for the main Dashboard strip.
class NoteSummary {
  final int total;
  final Note? recent;

  const NoteSummary({required this.total, required this.recent});
}

/// ---------------------------------------------------------------------------
/// NOTE SERVICE
/// All Firestore logic for notes, saved user-wise at:
///   users/{uid}/notes/{noteId}
/// Firestore only — no Firebase Storage.
/// ---------------------------------------------------------------------------
class NoteService {
  NoteService._();

  static final NoteService instance = NoteService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notes() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw NoteException('You are not logged in. Please login again.');
    }
    return _db.collection('users').doc(user.uid).collection('notes');
  }

  /// Loads all notes: pinned first, then newest edit first.
  /// Sorting is done in the app, so no Firestore composite index is needed.
  Future<List<Note>> loadNotes() async {
    try {
      final snapshot = await _notes()
          .orderBy('updatedAt', descending: true)
          .get();
      final notes = snapshot.docs.map(Note.fromDoc).toList();
      notes.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return notes;
    } on FirebaseException catch (e) {
      throw NoteException('Could not load notes: ${e.message}');
    }
  }

  /// Creates a new note and returns it with its Firestore id.
  Future<Note> addNote(Note note) async {
    try {
      final ref = await _notes().add(note.toMap());
      return note.copyWith(id: ref.id);
    } on FirebaseException catch (e) {
      throw NoteException('Could not save the note: ${e.message}');
    }
  }

  /// Updates an edited note (title / content / category + updatedAt).
  Future<void> updateNote(Note note) async {
    try {
      await _notes().doc(note.id).update({
        'title': note.title,
        'content': note.content,
        'category': note.category,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } on FirebaseException catch (e) {
      throw NoteException('Could not update the note: ${e.message}');
    }
  }

  Future<void> setFavorite(Note note, bool isFavorite) async {
    try {
      await _notes().doc(note.id).update({'isFavorite': isFavorite});
    } on FirebaseException catch (e) {
      throw NoteException('Could not update favorite: ${e.message}');
    }
  }

  Future<void> setPinned(Note note, bool isPinned) async {
    try {
      await _notes().doc(note.id).update({'isPinned': isPinned});
    } on FirebaseException catch (e) {
      throw NoteException('Could not update pin: ${e.message}');
    }
  }

  Future<void> deleteNote(Note note) async {
    try {
      await _notes().doc(note.id).delete();
    } on FirebaseException catch (e) {
      throw NoteException('Could not delete the note: ${e.message}');
    }
  }

  /// Count + most recent note for the main Dashboard (#9).
  Future<NoteSummary> loadSummary() async {
    try {
      final countSnap = await _notes().count().get();
      final recentSnap = await _notes()
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      return NoteSummary(
        total: countSnap.count ?? 0,
        recent: recentSnap.docs.isEmpty
            ? null
            : Note.fromDoc(recentSnap.docs.first),
      );
    } on FirebaseException catch (e) {
      throw NoteException('Could not load notes: ${e.message}');
    }
  }
}
