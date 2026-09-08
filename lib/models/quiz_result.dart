import 'package:cloud_firestore/cloud_firestore.dart';

/// One finished quiz saved in Firestore (users/{uid}/quiz_history).
class QuizResult {
  final String id;
  final String topic;
  final int score;
  final int total;
  final DateTime createdAt;

  const QuizResult({
    required this.id,
    required this.topic,
    required this.score,
    required this.total,
    required this.createdAt,
  });

  /// Builds a result from a Firestore document.
  factory QuizResult.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return QuizResult(
      id: doc.id,
      topic: (data['topic'] ?? '') as String,
      score: ((data['score'] ?? 0) as num).toInt(),
      total: ((data['total'] ?? 0) as num).toInt(),
      // serverTimestamp can be null for a moment right after writing.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
