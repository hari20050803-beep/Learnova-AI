import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/chat_message.dart';
import '../models/flashcard.dart';
import '../models/quiz_question.dart';

/// Thrown by [GeminiService] with a message that is safe to show to the user.
class GeminiException implements Exception {
  final String message;

  GeminiException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// GEMINI SERVICE
/// All Gemini API logic lives here, so the AI screens stay clean and
/// only deal with UI. Uses the Gemini Flash model over the REST API.
/// ---------------------------------------------------------------------------
class GeminiService {
  GeminiService._();

  /// Single shared instance used by all AI screens.
  static final GeminiService instance = GeminiService._();

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ---------------------------------------------------------------------
  // PUBLIC METHODS (one per AI feature)
  // ---------------------------------------------------------------------

  /// AI Academic Chatbot: sends the whole conversation so Gemini
  /// remembers the context of earlier messages.
  Future<String> askChatbot(List<ChatMessage> history) {
    final contents = history
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'model',
            'parts': [
              {'text': message.text},
            ],
          },
        )
        .toList();

    return _generate(
      contents,
      systemInstruction:
          'You are Learnova AI, a friendly academic assistant for students. '
          'Answer study questions clearly and correctly. Keep answers short '
          'and well structured. Use simple language a student understands. '
          'Answer in plain text only: no markdown, no asterisks, no # signs.',
    );
  }

  /// AI Notes Summarizer: turns long notes into a short, clear summary.
  Future<String> summarizeNotes(String notes) {
    return _generate(
      [
        {
          'role': 'user',
          'parts': [
            {'text': notes},
          ],
        },
      ],
      systemInstruction:
          'You are a study notes summarizer. Summarize the notes the user '
          'sends into short, clear bullet points a student can revise from. '
          'Keep every important fact. Start directly with the summary. '
          'Use plain text only: start each point with "•", and do not use '
          'markdown, asterisks or # signs.',
    );
  }

  /// AI Quiz Generator: asks Gemini for questions in JSON and parses them.
  Future<List<QuizQuestion>> generateQuiz(String topic, int count) async {
    final String raw = await _generate([
      {
        'role': 'user',
        'parts': [
          {
            'text':
                'Create $count multiple choice questions about: $topic. '
                'Return ONLY a valid JSON array, no markdown, no extra '
                'text. Each item must look like: '
                '{"question": "...", "options": ["...", "...", "...", '
                '"..."], "answerIndex": 0}. '
                'Exactly 4 options per question. answerIndex is the '
                'position (0-3) of the correct option.',
          },
        ],
      },
    ]);

    return _parseQuiz(raw);
  }

  /// AI Flashcards: asks Gemini for [count] flashcards about [content]
  /// (a topic the user typed, or the text of a saved note) and parses them.
  /// [subject] is the label stored on each card (the topic name or note title).
  Future<List<Flashcard>> generateFlashcards({
    required String content,
    required int count,
    required String subject,
  }) async {
    final String raw = await _generate([
      {
        'role': 'user',
        'parts': [
          {
            'text':
                'Create $count study flashcards from the following topic or '
                'notes:\n\n$content\n\n'
                'Return ONLY a valid JSON array, no markdown, no extra text. '
                'Each item must look like: '
                '{"question": "...", "answer": "...", '
                '"difficulty": "Easy|Medium|Hard"}. '
                'Keep each question clear and each answer short (1-3 '
                'sentences). Set difficulty to Easy, Medium or Hard.',
          },
        ],
      },
    ]);

    return _parseFlashcards(raw, subject);
  }

  /// AI Study Roadmap: builds a personalized study plan for [subject] with the
  /// exam on [examDate], [studyHours] hours per day and a [skillLevel]
  /// starting point. Returns the plan as plain text.
  Future<String> generateRoadmap({
    required String subject,
    required DateTime examDate,
    required int studyHours,
    required String skillLevel,
  }) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime exam = DateTime(examDate.year, examDate.month, examDate.day);
    final int daysLeft = exam.difference(today).inDays;
    final String examText =
        '${examDate.year}-${examDate.month.toString().padLeft(2, '0')}-'
        '${examDate.day.toString().padLeft(2, '0')}';

    return _generate(
      [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'Subject: $subject\n'
                  'Exam date: $examText (about $daysLeft days from today)\n'
                  'Current skill level: $skillLevel\n'
                  'Study hours available per day: $studyHours\n'
                  'Create a personalized study roadmap for me.',
            },
          ],
        },
      ],
      systemInstruction:
          'You are Learnova AI, a study planner for students. Build a clear, '
          'realistic and personalized study roadmap from the details the user '
          'gives (subject, exam date, days left, skill level, study hours per '
          'day). The roadmap MUST contain these sections, in this order, each '
          'with a heading in CAPITALS on its own line:\n'
          'DAILY STUDY PLAN, WEEKLY MILESTONES, REVISION DAYS, AI QUIZ DAYS, '
          'AI FLASHCARD REVISION DAYS, FINAL REVISION SCHEDULE.\n'
          'Spread the topics across the available days, increase difficulty as '
          'the skill level allows, and keep the last few days before the exam '
          'for final revision. Tell the student which days to take an AI quiz '
          'and which days to revise with AI flashcards (these are features of '
          'this app). Use plain text only: start each point with "•", write '
          'section headings in CAPITALS, and do NOT use markdown, asterisks, '
          '# signs or tables.',
    );
  }

  /// Study Materials: reads a PDF or image and returns a short, clear
  /// revision summary in plain text.
  Future<String> summarizeFile({
    required Uint8List bytes,
    required String mimeType,
  }) {
    return _generate([
      {
        'role': 'user',
        'parts': [
          {
            'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
          },
          {
            'text':
                'Summarize this study material into short, clear bullet '
                'points a student can revise from. Keep every important '
                'fact. Use plain text only: start each point with "•", and '
                'do not use markdown, asterisks or # signs.',
          },
        ],
      },
    ]);
  }

  /// Study Reminders: reads a screenshot or PDF (timetable, assignment
  /// brief, exam notice...) and extracts ONE reminder as JSON fields.
  Future<Map<String, dynamic>> extractReminderFromFile({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    const List<String> weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final DateTime today = DateTime.now();
    final String todayText =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')} '
        '(${weekdays[today.weekday - 1]})';

    final String raw = await _generate([
      {
        'role': 'user',
        'parts': [
          {
            'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
          },
          {
            'text':
                'This file is a student document: a class timetable, an '
                'assignment brief, an exam notice or a study plan. '
                'Today is $todayText. Extract the SINGLE most important '
                'upcoming item and return ONLY this JSON object, no '
                'markdown, no extra text: '
                '{"kind": "timetable|assignment|exam|study", '
                '"title": "...", "subject": "...", '
                '"dayOfWeek": 1-7 or null (1=Monday, only for timetable), '
                '"date": "YYYY-MM-DD" or null, '
                '"startTime": "HH:MM" or null, '
                '"endTime": "HH:MM" or null, '
                '"location": "..." or null, '
                '"lecturer": "..." or null, '
                '"notes": "..." or null}. '
                'Use null when something is not in the document.',
          },
        ],
      },
    ]);

    // Cut everything outside the JSON object and parse it.
    final int start = raw.indexOf('{');
    final int end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw GeminiException(
        'Could not read any reminder details from this file.',
      );
    }
    try {
      return jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw GeminiException(
        'Could not read any reminder details from this file.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------

  /// Sends one generateContent request to Gemini and returns the text.
  Future<String> _generate(
    List<Map<String, dynamic>> contents, {
    String? systemInstruction,
  }) async {
    if (ApiConfig.isKeyMissing) {
      throw GeminiException(
        'Gemini API key is missing. Open lib/config/api_config.dart '
        'and paste your API key.',
      );
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/${ApiConfig.geminiModel}:generateContent',
    );

    final Map<String, dynamic> body = {
      'contents': contents,
      if (systemInstruction != null)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
    };

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': ApiConfig.geminiApiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw GeminiException('Gemini took too long to answer. Try again.');
    } catch (_) {
      throw GeminiException(
        'Could not reach Gemini. Check your internet connection.',
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw GeminiException('Gemini sent an unexpected response. Try again.');
    }

    if (response.statusCode != 200) {
      throw GeminiException(_friendlyApiError(response.statusCode, data));
    }

    final String? text = _extractText(data);
    if (text == null || text.trim().isEmpty) {
      throw GeminiException(
        'Gemini returned no answer (the question may have been blocked). '
        'Try rephrasing.',
      );
    }
    return text.trim();
  }

  /// Pulls the answer text out of the Gemini response JSON.
  String? _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final parts = candidates.first['content']?['parts'];
      if (parts is List && parts.isNotEmpty) {
        final text = parts.first['text'];
        if (text is String) return text;
      }
    }
    return null;
  }

  /// Converts Gemini API errors into messages users can understand.
  String _friendlyApiError(int statusCode, Map<String, dynamic> data) {
    final String message =
        (data['error'] is Map ? data['error']['message'] : null) ??
        'Unknown error';

    if (statusCode == 400 && message.contains('API key')) {
      return 'Your Gemini API key is not valid. Check the key in '
          'lib/config/api_config.dart.';
    }
    if (statusCode == 429) {
      return 'Too many requests to Gemini. Wait a minute and try again.';
    }
    if (statusCode == 404) {
      return 'Gemini model not found. Check geminiModel in '
          'lib/config/api_config.dart.';
    }
    if (statusCode >= 500) {
      return 'Gemini servers are busy right now. Try again in a moment.';
    }
    return 'Gemini error: $message';
  }

  /// Parses the JSON quiz that Gemini returns (and survives the common
  /// case where the model wraps it in a ```json code fence anyway).
  List<QuizQuestion> _parseQuiz(String raw) {
    String text = raw.trim();

    // Cut everything outside the first '[' and the last ']'.
    final int start = text.indexOf('[');
    final int end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) {
      throw GeminiException('Could not read the quiz. Try again.');
    }
    text = text.substring(start, end + 1);

    try {
      final List<dynamic> list = jsonDecode(text) as List<dynamic>;
      final questions = list
          .map((item) => QuizQuestion.fromJson(item as Map<String, dynamic>))
          .where(
            (q) =>
                q.options.length >= 2 &&
                q.answerIndex >= 0 &&
                q.answerIndex < q.options.length,
          )
          .toList();
      if (questions.isEmpty) {
        throw GeminiException('The quiz came back empty. Try again.');
      }
      return questions;
    } on GeminiException {
      rethrow;
    } catch (_) {
      throw GeminiException('Could not read the quiz. Try again.');
    }
  }

  /// Parses the JSON flashcards that Gemini returns (and survives the common
  /// case where the model wraps it in a ```json code fence anyway).
  /// [subject] is attached to every card, since it is not in the AI response.
  List<Flashcard> _parseFlashcards(String raw, String subject) {
    String text = raw.trim();

    // Cut everything outside the first '[' and the last ']'.
    final int start = text.indexOf('[');
    final int end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) {
      throw GeminiException('Could not read the flashcards. Try again.');
    }
    text = text.substring(start, end + 1);

    try {
      final List<dynamic> list = jsonDecode(text) as List<dynamic>;
      final cards = list
          .map(
            (item) => Flashcard.fromJson(
              item as Map<String, dynamic>,
              subject: subject,
            ),
          )
          .where(
            (c) => c.question.trim().isNotEmpty && c.answer.trim().isNotEmpty,
          )
          .toList();
      if (cards.isEmpty) {
        throw GeminiException('The flashcards came back empty. Try again.');
      }
      return cards;
    } on GeminiException {
      rethrow;
    } catch (_) {
      throw GeminiException('Could not read the flashcards. Try again.');
    }
  }
}
