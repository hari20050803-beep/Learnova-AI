import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/study_roadmap.dart';

/// Thrown by [RoadmapService] with a message safe to show to the user.
class RoadmapException implements Exception {
  final String message;

  RoadmapException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// ROADMAP SERVICE
/// All Firestore logic for AI study roadmaps, saved user-wise at:
///   users/{uid}/study_roadmaps/{roadmapId}
/// ---------------------------------------------------------------------------
class RoadmapService {
  RoadmapService._();

  static final RoadmapService instance = RoadmapService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _roadmaps() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw RoadmapException('You are not logged in. Please login again.');
    }
    return _db.collection('users').doc(user.uid).collection('study_roadmaps');
  }

  /// Saves a new roadmap and returns it with its Firestore id.
  Future<StudyRoadmap> saveRoadmap(StudyRoadmap roadmap) async {
    try {
      final ref = await _roadmaps().add(roadmap.toMap());
      return roadmap.copyWith(id: ref.id);
    } on FirebaseException catch (e) {
      throw RoadmapException('Could not save the roadmap: ${e.message}');
    }
  }

  /// Loads all roadmaps of the current user, newest first.
  Future<List<StudyRoadmap>> loadRoadmaps() async {
    try {
      final snapshot = await _roadmaps()
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map(StudyRoadmap.fromDoc).toList();
    } on FirebaseException catch (e) {
      throw RoadmapException('Could not load roadmaps: ${e.message}');
    }
  }

  /// Deletes one roadmap.
  Future<void> deleteRoadmap(String id) async {
    try {
      await _roadmaps().doc(id).delete();
    } on FirebaseException catch (e) {
      throw RoadmapException('Could not delete the roadmap: ${e.message}');
    }
  }
}
