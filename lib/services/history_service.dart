import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/dashboard_stats.dart';
import '../models/quiz_result.dart';
import '../models/summary_entry.dart';

/// Thrown by [HistoryService] with a message that is safe to show to the user.
class HistoryException implements Exception {
  final String message;

  HistoryException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// HISTORY SERVICE
/// Saves and loads the user's AI activity in Firestore, always under the
/// logged-in user's UID:
///   users/{uid}/chat_sessions/{sessionId}            - one chat conversation
///   users/{uid}/chat_sessions/{sessionId}/messages   - its messages
///   users/{uid}/quiz_history                         - finished quiz results
///   users/{uid}/summaries                            - notes + summaries
/// ---------------------------------------------------------------------------
class HistoryService {
  HistoryService._();

  /// Single shared instance used by all AI screens.
  static final HistoryService instance = HistoryService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Subcollection of the CURRENT user. Throws if nobody is logged in.
  CollectionReference<Map<String, dynamic>> _collection(String name) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw HistoryException('You are not logged in. Please login again.');
    }
    return _db.collection('users').doc(user.uid).collection(name);
  }

  /// The messages of one chat session.
  CollectionReference<Map<String, dynamic>> _messages(String sessionId) {
    return _collection('chat_sessions').doc(sessionId).collection('messages');
  }

  // ---------------------------------------------------------------------
  // CHAT SESSIONS (users/{uid}/chat_sessions) - ChatGPT style
  // ---------------------------------------------------------------------

  /// Loads all chat sessions: pinned first, newest activity first.
  Future<List<ChatSession>> loadChatSessions() async {
    try {
      final snapshot = await _collection(
        'chat_sessions',
      ).orderBy('updatedAt', descending: true).get();
      final sessions = snapshot.docs.map(ChatSession.fromDoc).toList();
      // Pinned chats go to the top (sorted in the app, so no special
      // Firestore index is needed).
      sessions.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return sessions;
    } on FirebaseException catch (e) {
      throw HistoryException('Could not load chats: ${e.message}');
    }
  }

  /// Creates a new chat session (called when the first message is sent).
  Future<ChatSession> createChatSession(String title) async {
    try {
      final ref = await _collection('chat_sessions').add({
        'title': title,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isPinned': false,
      });
      final now = DateTime.now();
      return ChatSession(
        id: ref.id,
        title: title,
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );
    } on FirebaseException catch (e) {
      throw HistoryException('Could not create the chat: ${e.message}');
    }
  }

  /// Loads the messages of one session, oldest first.
  Future<List<ChatMessage>> loadSessionMessages(String sessionId) async {
    try {
      final snapshot = await _messages(sessionId).orderBy('createdAt').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          text: (data['text'] ?? '') as String,
          isUser: (data['isUser'] ?? false) as bool,
        );
      }).toList();
    } on FirebaseException catch (e) {
      throw HistoryException('Could not load this chat: ${e.message}');
    }
  }

  /// Saves one message into a session and bumps the session's updatedAt
  /// (so the most recently used chat moves to the top of the list).
  Future<void> saveSessionMessage(String sessionId, ChatMessage message) async {
    try {
      await _messages(sessionId).add({
        'text': message.text,
        'isUser': message.isUser,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _collection(
        'chat_sessions',
      ).doc(sessionId).update({'updatedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      throw HistoryException('Could not save the message: ${e.message}');
    }
  }

  /// Pins or unpins a chat session.
  Future<void> setSessionPinned(String sessionId, bool isPinned) async {
    try {
      await _collection(
        'chat_sessions',
      ).doc(sessionId).update({'isPinned': isPinned});
    } on FirebaseException catch (e) {
      throw HistoryException('Could not update the pin: ${e.message}');
    }
  }

  /// Deletes a chat session and all of its messages.
  Future<void> deleteChatSession(String sessionId) async {
    try {
      final messages = await _messages(sessionId).get();
      final WriteBatch batch = _db.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_collection('chat_sessions').doc(sessionId));
      await batch.commit();
    } on FirebaseException catch (e) {
      throw HistoryException('Could not delete the chat: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------
  // QUIZ HISTORY (users/{uid}/quiz_history)
  // ---------------------------------------------------------------------

  /// Saves one finished quiz and returns it (with its new document id).
  Future<QuizResult> saveQuizResult({
    required String topic,
    required int score,
    required int total,
  }) async {
    try {
      final ref = await _collection('quiz_history').add({
        'topic': topic,
        'score': score,
        'total': total,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return QuizResult(
        id: ref.id,
        topic: topic,
        score: score,
        total: total,
        createdAt: DateTime.now(),
      );
    } on FirebaseException catch (e) {
      throw HistoryException('Could not save the quiz result: ${e.message}');
    }
  }

  /// Loads past quiz results, newest first.
  Future<List<QuizResult>> loadQuizHistory() async {
    try {
      final snapshot = await _collection(
        'quiz_history',
      ).orderBy('createdAt', descending: true).get();
      return snapshot.docs.map(QuizResult.fromDoc).toList();
    } on FirebaseException catch (e) {
      throw HistoryException('Could not load quiz history: ${e.message}');
    }
  }

  /// Deletes one quiz result.
  Future<void> deleteQuizResult(String id) => _deleteDoc('quiz_history', id);

  // ---------------------------------------------------------------------
  // SUMMARIES (users/{uid}/summaries)
  // ---------------------------------------------------------------------

  /// Saves one summary and returns it (with its new document id).
  Future<SummaryEntry> saveSummary({
    required String notes,
    required String summary,
  }) async {
    try {
      final ref = await _collection('summaries').add({
        'notes': notes,
        'summary': summary,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return SummaryEntry(
        id: ref.id,
        notes: notes,
        summary: summary,
        createdAt: DateTime.now(),
      );
    } on FirebaseException catch (e) {
      throw HistoryException('Could not save the summary: ${e.message}');
    }
  }

  /// Loads past summaries, newest first.
  Future<List<SummaryEntry>> loadSummaries() async {
    try {
      final snapshot = await _collection(
        'summaries',
      ).orderBy('createdAt', descending: true).get();
      return snapshot.docs.map(SummaryEntry.fromDoc).toList();
    } on FirebaseException catch (e) {
      throw HistoryException('Could not load summaries: ${e.message}');
    }
  }

  /// Deletes one summary.
  Future<void> deleteSummary(String id) => _deleteDoc('summaries', id);

  // ---------------------------------------------------------------------
  // DASHBOARD ANALYTICS (counts + recent activity)
  // ---------------------------------------------------------------------

  /// Loads the totals and the most recent activity for the
  /// Progress Dashboard screen.
  Future<DashboardStats> loadDashboardStats() async {
    try {
      // Fast count queries (no documents are downloaded).
      final chatCount = await _collection('chat_sessions').count().get();
      final quizCount = await _collection('quiz_history').count().get();
      final summaryCount = await _collection('summaries').count().get();

      // Latest 3 of each activity type.
      final recentChats = await _collection(
        'chat_sessions',
      ).orderBy('updatedAt', descending: true).limit(3).get();
      final recentQuizzes = await _collection(
        'quiz_history',
      ).orderBy('createdAt', descending: true).limit(3).get();
      final recentSummaries = await _collection(
        'summaries',
      ).orderBy('createdAt', descending: true).limit(3).get();

      final List<ActivityItem> activity = [
        for (final doc in recentChats.docs.map(ChatSession.fromDoc))
          ActivityItem(type: 'chat', title: doc.title, date: doc.updatedAt),
        for (final doc in recentQuizzes.docs.map(QuizResult.fromDoc))
          ActivityItem(
            type: 'quiz',
            title: 'Quiz: ${doc.topic} (${doc.score}/${doc.total})',
            date: doc.createdAt,
          ),
        for (final doc in recentSummaries.docs.map(SummaryEntry.fromDoc))
          ActivityItem(
            type: 'summary',
            title: doc.summary,
            date: doc.createdAt,
          ),
      ];
      // Newest first, keep the top 6.
      activity.sort((a, b) => b.date.compareTo(a.date));

      return DashboardStats(
        totalChats: chatCount.count ?? 0,
        totalQuizzes: quizCount.count ?? 0,
        totalSummaries: summaryCount.count ?? 0,
        recentActivity: activity.take(6).toList(),
      );
    } on FirebaseException catch (e) {
      throw HistoryException('Could not load your stats: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------
  // SHARED HELPERS
  // ---------------------------------------------------------------------

  Future<void> _deleteDoc(String collection, String id) async {
    try {
      await _collection(collection).doc(id).delete();
    } on FirebaseException catch (e) {
      throw HistoryException('Could not delete: ${e.message}');
    }
  }
}
