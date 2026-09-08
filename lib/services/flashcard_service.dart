import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/flashcard.dart';

/// Thrown by [FlashcardService] with a message safe to show to the user.
class FlashcardException implements Exception {
  final String message;

  FlashcardException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// FLASHCARD SERVICE
/// All Firestore logic for AI flashcards, saved user-wise at:
///   users/{uid}/flashcards/{flashcardId}
/// ---------------------------------------------------------------------------
class FlashcardService {
  FlashcardService._();

  static final FlashcardService instance = FlashcardService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _flashcards() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FlashcardException('You are not logged in. Please login again.');
    }
    return _db.collection('users').doc(user.uid).collection('flashcards');
  }

  /// Saves a freshly generated batch of flashcards and returns them with their
  /// Firestore ids. One WriteBatch is used so every card saves together.
  Future<List<Flashcard>> saveFlashcards(List<Flashcard> cards) async {
    try {
      final collection = _flashcards();
      final WriteBatch batch = _db.batch();
      final List<Flashcard> saved = [];
      for (final card in cards) {
        final ref = collection.doc(); // auto-generated id
        batch.set(ref, card.toMap());
        saved.add(card.copyWith(id: ref.id));
      }
      await batch.commit();
      return saved;
    } on FirebaseException catch (e) {
      throw FlashcardException('Could not save the flashcards: ${e.message}');
    }
  }

  /// Loads all flashcards of the current user, newest first.
  Future<List<Flashcard>> loadFlashcards() async {
    try {
      final snapshot = await _flashcards()
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(Flashcard.fromDoc).toList();
    } on FirebaseException catch (e) {
      throw FlashcardException('Could not load flashcards: ${e.message}');
    }
  }

  /// Updates the study status of one card (new / known / revision).
  Future<void> updateStatus(Flashcard card, String status) async {
    try {
      await _flashcards().doc(card.id).update({'status': status});
    } on FirebaseException catch (e) {
      throw FlashcardException('Could not update the flashcard: ${e.message}');
    }
  }

  /// Flips the favorite flag on one card.
  Future<void> toggleFavorite(Flashcard card, bool isFavorite) async {
    try {
      await _flashcards().doc(card.id).update({'isFavorite': isFavorite});
    } on FirebaseException catch (e) {
      throw FlashcardException('Could not update favorite: ${e.message}');
    }
  }

  /// Deletes one flashcard.
  Future<void> deleteFlashcard(Flashcard card) async {
    try {
      await _flashcards().doc(card.id).delete();
    } on FirebaseException catch (e) {
      throw FlashcardException('Could not delete the flashcard: ${e.message}');
    }
  }
}
