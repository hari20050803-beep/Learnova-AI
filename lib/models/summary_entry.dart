import 'package:cloud_firestore/cloud_firestore.dart';

/// One saved summary in Firestore (users/{uid}/summaries).
class SummaryEntry {
  final String id;
  final String notes;
  final String summary;
  final DateTime createdAt;

  const SummaryEntry({
    required this.id,
    required this.notes,
    required this.summary,
    required this.createdAt,
  });

  /// Builds an entry from a Firestore document.
  factory SummaryEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SummaryEntry(
      id: doc.id,
      notes: (data['notes'] ?? '') as String,
      summary: (data['summary'] ?? '') as String,
      // serverTimestamp can be null for a moment right after writing.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
