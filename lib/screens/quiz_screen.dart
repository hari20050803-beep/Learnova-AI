import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../models/quiz_question.dart';
import '../models/quiz_result.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_date.dart';
import '../widgets/animations.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_header.dart';

/// This module's accent, so the chips, banner and spinner match its header
/// instead of falling back to the generic brand indigo.
const ModuleAccent _accent = ModuleAccent.quiz;

/// ---------------------------------------------------------------------------
/// AI QUIZ GENERATOR (powered by Gemini)
/// Enter a topic, Gemini creates multiple-choice questions, the student
/// answers them with instant feedback, and the final score is saved in
/// Firestore (users/{uid}/quiz_history) and shown under "Past Results".
/// ---------------------------------------------------------------------------
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _topicController = TextEditingController();

  int _questionCount = 5;
  bool _isLoading = false;
  List<QuizQuestion> _questions = [];

  /// question index -> option index the student picked.
  final Map<int, int> _selectedAnswers = {};

  /// Makes sure each finished quiz is saved only once.
  bool _resultSaved = false;

  /// Saved results from Firestore (newest first).
  List<QuizResult> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int get _score {
    int score = 0;
    _selectedAnswers.forEach((questionIndex, optionIndex) {
      if (_questions[questionIndex].answerIndex == optionIndex) score++;
    });
    return score;
  }

  bool get _quizFinished =>
      _questions.isNotEmpty && _selectedAnswers.length == _questions.length;

  /// Loads past quiz results when the screen opens.
  Future<void> _loadHistory() async {
    try {
      final saved = await HistoryService.instance.loadQuizHistory();
      if (!mounted) return;
      setState(() => _history = saved);
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  /// Saves the finished quiz to Firestore and shows it in "Past Results".
  Future<void> _saveResult() async {
    try {
      final result = await HistoryService.instance.saveQuizResult(
        topic: _topicController.text.trim(),
        score: _score,
        total: _questions.length,
      );
      if (!mounted) return;
      setState(() => _history.insert(0, result));
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  /// Asks the user, then deletes one saved result.
  Future<void> _deleteResult(QuizResult result) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this result?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await HistoryService.instance.deleteQuizResult(result.id);
      if (!mounted) return;
      setState(() => _history.removeWhere((r) => r.id == result.id));
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _generateQuiz() async {
    final String topic = _topicController.text.trim();

    if (topic.isEmpty) {
      _showError('Please enter a topic for the quiz.');
      return;
    }

    setState(() {
      _isLoading = true;
      _questions = [];
      _selectedAnswers.clear();
      _resultSaved = false;
    });

    try {
      // Real Gemini call (returns parsed questions).
      final questions = await GeminiService.instance.generateQuiz(
        topic,
        _questionCount,
      );

      if (!mounted) return;
      setState(() => _questions = questions);
    } on GeminiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onOptionSelected(int questionIndex, int optionIndex) {
    // Lock the answer after the first tap.
    if (_selectedAnswers.containsKey(questionIndex)) return;
    setState(() => _selectedAnswers[questionIndex] = optionIndex);

    // When the last question is answered, save the result once.
    if (_quizFinished && !_resultSaved) {
      _resultSaved = true;
      _saveResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Quiz Generator')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ----- Brand hero header -----
              FadeSlideIn(
                child: GradientHeader(
                  icon: Icons.quiz_rounded,
                  title: 'Create a practice quiz',
                  subtitle:
                      'Enter a topic and get instant multiple-choice questions.',
                  accent: ModuleAccent.quiz,
                  heroTag: moduleHeroTag(FeatureType.quiz),
                ),
              ),
              const SizedBox(height: 20),

              // ----- Topic input card -----
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.cardShadow(context),
                  border: AppColors.cardBorder(context),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        hintText:
                            'Topic, e.g. Operating Systems, Photosynthesis',
                        prefixIcon: Icon(Icons.topic_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Number of questions.
                    Row(
                      children: [
                        Text(
                          'Questions:',
                          style: TextStyle(
                            color: AppColors.subText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        for (final count in [3, 5, 10]) ...[
                          ChoiceChip(
                            label: Text('$count'),
                            selected: _questionCount == count,
                            selectedColor: _accent.end,
                            labelStyle: TextStyle(
                              color: _questionCount == count
                                  ? Colors.white
                                  : AppColors.text(context),
                            ),
                            onSelected: (_) {
                              setState(() => _questionCount = count);
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      text: 'Generate Quiz',
                      isLoading: _isLoading,
                      onPressed: _generateQuiz,
                    ),
                  ],
                ),
              ),

              // ----- Score banner (after all questions answered) -----
              if (_quizFinished) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: _accent.gradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.start.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Your score: $_score / ${_questions.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ----- Questions (appear one by one) -----
              for (int i = 0; i < _questions.length; i++) ...[
                const SizedBox(height: 20),
                FadeSlideIn(
                  delay: Duration(milliseconds: 80 * i),
                  child: _QuestionCard(
                    number: i + 1,
                    question: _questions[i],
                    selectedOption: _selectedAnswers[i],
                    onOptionSelected: (option) => _onOptionSelected(i, option),
                  ),
                ),
              ],

              // ----- Past results from Firestore -----
              if (_isLoadingHistory) ...[
                const SizedBox(height: 24),
                Center(child: CircularProgressIndicator(color: _accent.end)),
              ] else if (_history.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Past Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 10),
                for (final result in _history)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppColors.cardShadow(context),
                    ),
                    // ListTiles need their own Material surface for the
                    // background color (avoids a Flutter debug warning).
                    child: Material(
                      color: AppColors.card(context),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: AppColors.isDark(context)
                            ? BorderSide(
                                color: Colors.white.withValues(alpha: 0.06),
                              )
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: _accent.gradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          result.topic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: AppColors.text(context),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Score: ${result.score}/${result.total}  •  '
                            '${formatDateTime(result.createdAt)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.subText(context),
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete result',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                          ),
                          onPressed: () => _deleteResult(result),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One question with its tappable options.
/// After answering: the correct option turns green, a wrong pick turns red.
class _QuestionCard extends StatelessWidget {
  final int number;
  final QuizQuestion question;
  final int? selectedOption;
  final ValueChanged<int> onOptionSelected;

  const _QuestionCard({
    required this.number,
    required this.question,
    required this.selectedOption,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool answered = selectedOption != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q$number. ${question.question}',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (int o = 0; o < question.options.length; o++)
            _OptionTile(
              text: question.options[o],
              state: _stateFor(o, answered),
              onTap: () => onOptionSelected(o),
            ),
        ],
      ),
    );
  }

  _OptionState _stateFor(int option, bool answered) {
    if (!answered) return _OptionState.idle;
    if (option == question.answerIndex) return _OptionState.correct;
    if (option == selectedOption) return _OptionState.wrong;
    return _OptionState.disabled;
  }
}

enum _OptionState { idle, correct, wrong, disabled }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionTile({
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color textColor;
    IconData? icon;

    switch (state) {
      case _OptionState.correct:
        background = Colors.green.shade600;
        textColor = Colors.white;
        icon = Icons.check_circle_rounded;
      case _OptionState.wrong:
        background = Colors.red.shade600;
        textColor = Colors.white;
        icon = Icons.cancel_rounded;
      case _OptionState.disabled:
        background = AppColors.isDark(context)
            ? const Color(0xFF222A4D)
            : const Color(0xFFF3F4F8);
        textColor = AppColors.subText(context);
      case _OptionState.idle:
        background = AppColors.isDark(context)
            ? const Color(0xFF222A4D)
            : const Color(0xFFF3F4F8);
        textColor = AppColors.text(context);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
              ),
            ),
            if (icon != null) Icon(icon, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
