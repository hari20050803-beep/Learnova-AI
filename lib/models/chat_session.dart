import 'package:cloud_firestore/cloud_firestore.dart';

/// One chat conversation saved in Firestore (users/{uid}/chat_sessions).
/// The actual messages live in the "messages" subcollection of the session.
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
  });

  /// Builds a session from a Firestore document.
  factory ChatSession.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ChatSession(
      id: doc.id,
      title: (data['title'] ?? 'New chat') as String,
      // serverTimestamp can be null for a moment right after writing.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPinned: (data['isPinned'] ?? false) as bool,
    );
  }

  /// Copy of this session with some fields changed.
  ChatSession copyWith({String? title, DateTime? updatedAt, bool? isPinned}) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
