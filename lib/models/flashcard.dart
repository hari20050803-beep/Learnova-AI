import 'package:cloud_firestore/cloud_firestore.dart';

/// Difficulty levels an AI flashcard can have.
const List<String> kFlashcardDifficulties = ['Easy', 'Medium', 'Hard'];

/// Study status keys stored in Firestore (kept lowercase, like
/// StudyReminder.kind). Use [Flashcard.statusLabel] for the display text.
const String kFlashcardStatusNew = 'new';
const String kFlashcardStatusKnown = 'known';
const String kFlashcardStatusRevision = 'revision';

/// ---------------------------------------------------------------------------
/// FLASHCARD (one AI-generated flashcard) in Firestore:
///   users/{uid}/flashcards/{flashcardId}
/// ---------------------------------------------------------------------------
class Flashcard {
  final String id;
  final String question;
  final String answer;
  final String subject;

  /// One of [kFlashcardDifficulties] (Easy / Medium / Hard).
  final String difficulty;

  /// One of kFlashcardStatusNew / kFlashcardStatusKnown /
  /// kFlashcardStatusRevision.
  final String status;

  final bool isFavorite;
  final DateTime createdAt;

  const Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.subject,
    required this.difficulty,
    required this.status,
    required this.isFavorite,
    required this.createdAt,
  });

  /// Builds a flashcard from a saved Firestore document.
  factory Flashcard.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Flashcard(
      id: doc.id,
      question: (data['question'] ?? '') as String,
      answer: (data['answer'] ?? '') as String,
      subject: (data['subject'] ?? '') as String,
      difficulty: (data['difficulty'] ?? 'Medium') as String,
      status: (data['status'] ?? kFlashcardStatusNew) as String,
      isFavorite: (data['isFavorite'] ?? false) as bool,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Builds a flashcard from the JSON that Gemini returns:
  ///   {"question": "...", "answer": "...", "difficulty": "..."}
  /// [subject] is supplied by the caller (the topic or note title), because it
  /// is not part of the AI response. A brand new card starts as "new".
  factory Flashcard.fromJson(Map<String, dynamic> json, {String subject = ''}) {
    return Flashcard(
      id: '',
      question: (json['question'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      subject: subject,
      difficulty: _normalizeDifficulty(json['difficulty']),
      status: kFlashcardStatusNew,
      isFavorite: false,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'question': question,
    'answer': answer,
    'subject': subject,
    'difficulty': difficulty,
    'status': status,
    'isFavorite': isFavorite,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  Flashcard copyWith({
    String? id,
    String? subject,
    String? difficulty,
    String? status,
    bool? isFavorite,
  }) {
    return Flashcard(
      id: id ?? this.id,
      question: question,
      answer: answer,
      subject: subject ?? this.subject,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }

  /// Human-friendly label for [status] (used on the study screen).
  String get statusLabel {
    switch (status) {
      case kFlashcardStatusKnown:
        return 'Known';
      case kFlashcardStatusRevision:
        return 'Need Revision';
      default:
        return 'New';
    }
  }

  /// Maps any AI difficulty text onto Easy / Medium / Hard (defaults Medium).
  static String _normalizeDifficulty(dynamic raw) {
    final String value = (raw ?? '').toString().trim().toLowerCase();
    if (value.startsWith('easy')) return 'Easy';
    if (value.startsWith('hard')) return 'Hard';
    return 'Medium';
  }
}
