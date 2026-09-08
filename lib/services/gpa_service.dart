import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gpa_record.dart';

/// Thrown by [GpaService] with a message safe to show to the user.
class GpaException implements Exception {
  final String message;

  GpaException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// GPA SERVICE
/// All Firestore logic for GPA records, saved user-wise at:
///   users/{uid}/gpa_records/{recordId}
/// ---------------------------------------------------------------------------
class GpaService {
  GpaService._();

  static final GpaService instance = GpaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _records() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw GpaException('You are not logged in. Please login again.');
    }
    return _db.collection('users').doc(user.uid).collection('gpa_records');
  }

  /// Saves a new GPA record and returns it with its Firestore id.
  Future<GpaRecord> saveRecord(GpaRecord record) async {
    try {
      final ref = await _records().add(record.toMap());
      return GpaRecord(
        id: ref.id,
        semesterName: record.semesterName,
        subjects: record.subjects,
        totalCredits: record.totalCredits,
        gpa: record.gpa,
        createdAt: record.createdAt,
      );
    } on FirebaseException catch (e) {
      throw GpaException('Could not save the GPA record: ${e.message}');
    }
  }

  /// Loads all saved GPA records, newest first.
  Future<List<GpaRecord>> loadRecords() async {
    try {
      final snapshot = await _records()
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(GpaRecord.fromDoc).toList();
    } on FirebaseException catch (e) {
      throw GpaException('Could not load GPA history: ${e.message}');
    }
  }

  /// Deletes one GPA record.
  Future<void> deleteRecord(String id) async {
    try {
      await _records().doc(id).delete();
    } on FirebaseException catch (e) {
      throw GpaException('Could not delete the GPA record: ${e.message}');
    }
  }

  /// Loads only the most recent record (used by the main Dashboard strip).
  /// Returns null when the user has no saved records yet.
  Future<GpaRecord?> loadLatest() async {
    try {
      final snapshot = await _records()
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return GpaRecord.fromDoc(snapshot.docs.first);
    } on FirebaseException catch (e) {
      throw GpaException('Could not load your latest GPA: ${e.message}');
    }
  }
}
