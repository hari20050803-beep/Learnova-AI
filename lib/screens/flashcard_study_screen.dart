import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../services/flashcard_service.dart';
import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// FLASHCARD STUDY SCREEN
/// Interactive study: tap the card to flip (3D Matrix4 rotation) between the
/// question and the answer, move Next / Previous with a progress bar, and mark
/// each card Known / Need Revision / Favorite. Changes are saved to Firestore.
/// ---------------------------------------------------------------------------
class FlashcardStudyScreen extends StatefulWidget {
  final List<Flashcard> cards;
  final int initialIndex;

  const FlashcardStudyScreen({
    super.key,
    required this.cards,
    this.initialIndex = 0,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen>
    with SingleTickerProviderStateMixin {
  /// A local, mutable copy so status / favorite changes show instantly.
  late final List<Flashcard> _cards;
  late int _index;
  late final AnimationController _flip;

  @override
  void initState() {
    super.initState();
    _cards = List.of(widget.cards);
    _index = widget.initialIndex.clamp(0, _cards.length - 1);
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Flashcard get _current => _cards[_index];

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Flip between the question and the answer.
  void _flipCard() {
    if (_flip.isAnimating) return;
    if (_flip.value < 0.5) {
      _flip.forward();
    } else {
      _flip.reverse();
    }
  }

  /// Moves to another card, always starting on the question side.
  void _go(int delta) {
    final int next = _index + delta;
    if (next < 0 || next >= _cards.length) return;
    _flip.reset();
    setState(() => _index = next);
  }

  Future<void> _mark(String status) async {
    final Flashcard card = _current;
    setState(() => _cards[_index] = card.copyWith(status: status));
    try {
      await FlashcardService.instance.updateStatus(card, status);
    } on FlashcardException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _toggleFavorite() async {
    final Flashcard card = _current;
    final bool newValue = !card.isFavorite;
    setState(() => _cards[_index] = card.copyWith(isFavorite: newValue));
    try {
      await FlashcardService.instance.toggleFavorite(card, newValue);
    } on FlashcardException catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Flashcard card = _current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Flashcards'),
        actions: [
          IconButton(
            tooltip: card.isFavorite ? 'Remove favorite' : 'Add to favorites',
            icon: Icon(
              card.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: card.isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ----- Progress -----
              Row(
                children: [
                  Text(
                    'Card ${_index + 1} of ${_cards.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.subText(context),
                    ),
                  ),
                  const Spacer(),
                  _statusBadge(card),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _cards.length,
                  minHeight: 8,
                  backgroundColor: AppColors.indigo.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppColors.indigo),
                ),
              ),
              const SizedBox(height: 20),

              // ----- Flip card (fills the middle space) -----
              Expanded(
                child: GestureDetector(
                  onTap: _flipCard,
                  child: _buildFlipCard(card),
                ),
              ),
              const SizedBox(height: 16),

              // ----- Known / Need Revision -----
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _mark(kFlashcardStatusKnown),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Known'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _mark(kFlashcardStatusRevision),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Need Revision'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ----- Previous / Next -----
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index > 0 ? () => _go(-1) : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.indigo,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _index < _cards.length - 1
                          ? () => _go(1)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The 3D flip: rotates the card on the Y axis and swaps the visible face
  /// at the half-way point (with an extra 180° flip so the back is not
  /// mirrored). Built only from Transform / Matrix4 — no packages.
  Widget _buildFlipCard(Flashcard card) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final double angle = _flip.value * math.pi;
        final bool showFront = angle <= math.pi / 2;
        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(angle);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: showFront
              ? _cardFace(card, isAnswer: false)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _cardFace(card, isAnswer: true),
                ),
        );
      },
    );
  }

  /// One face of the card. Question = normal card; Answer = brand gradient.
  Widget _cardFace(Flashcard card, {required bool isAnswer}) {
    final Color textColor = isAnswer ? Colors.white : AppColors.text(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isAnswer ? AppColors.mainGradient : null,
        color: isAnswer ? null : AppColors.card(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow(context),
        border: isAnswer ? null : AppColors.cardBorder(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip(
                card.subject.trim().isEmpty ? 'Flashcard' : card.subject,
                isAnswer,
              ),
              const Spacer(),
              _difficultyChip(card.difficulty, isAnswer),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            isAnswer ? 'ANSWER' : 'QUESTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isAnswer ? Colors.white70 : AppColors.subText(context),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  isAnswer ? card.answer : card.question,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              isAnswer ? 'Tap to see the question' : 'Tap to reveal the answer',
              style: TextStyle(
                fontSize: 12.5,
                color: isAnswer ? Colors.white70 : AppColors.subText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Flashcard card) {
    Color color;
    switch (card.status) {
      case kFlashcardStatusKnown:
        color = Colors.green.shade600;
      case kFlashcardStatusRevision:
        color = Colors.orange.shade700;
      default:
        color = AppColors.subText(context);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        card.statusLabel,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _chip(String text, bool onGradient) {
    final Color bg = onGradient
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.indigo.withValues(
            alpha: AppColors.isDark(context) ? 0.22 : 0.10,
          );
    final Color fg = onGradient
        ? Colors.white
        : (AppColors.isDark(context)
              ? const Color(0xFFB9B4FF)
              : AppColors.indigo);
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _difficultyChip(String difficulty, bool onGradient) {
    MaterialColor base;
    switch (difficulty) {
      case 'Easy':
        base = Colors.green;
      case 'Hard':
        base = Colors.red;
      default:
        base = Colors.orange;
    }
    final Color bg = onGradient
        ? Colors.white.withValues(alpha: 0.22)
        : base.withValues(alpha: 0.15);
    final Color fg = onGradient ? Colors.white : base.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
