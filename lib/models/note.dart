import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories a note can belong to.
const List<String> kNoteCategories = [
  'General',
  'Lecture',
  'Assignment',
  'Exam',
  'Idea',
  'Other',
];

/// ---------------------------------------------------------------------------
/// NOTE (one study note) in Firestore:
///   users/{uid}/notes/{noteId}
/// ---------------------------------------------------------------------------
class Note {
  final String id;
  final String title;
  final String content;
  final String category;
  final bool isFavorite;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.isFavorite,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Note(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      content: (data['content'] ?? '') as String,
      category: (data['category'] ?? 'General') as String,
      isFavorite: (data['isFavorite'] ?? false) as bool,
      isPinned: (data['isPinned'] ?? false) as bool,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'category': category,
    'isFavorite': isFavorite,
    'isPinned': isPinned,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    bool? isFavorite,
    bool? isPinned,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
