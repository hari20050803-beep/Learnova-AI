import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// AUTH ENTRANCE
/// The staged reveal shared by every sign-in screen: the header fades in
/// first, then the card fades and slides up just behind it, with the footer
/// riding along with the card.
///
/// This existed as ~25 duplicated lines in each of Login, Register, Forgot
/// Password, Reset Password and both OTP screens — five controllers, five sets
/// of identical Intervals, five chances to drift apart. It lives here now.
///
/// Timings are unchanged from the original screens: 1000ms total, header on
/// 0.0–0.55 easeIn, card on 0.3–1.0 (easeIn for opacity, easeOutCubic for the
/// slide).
/// ---------------------------------------------------------------------------
class AuthEntrance extends StatefulWidget {
  /// Logo, or icon + title. Fades in first.
  final Widget header;

  /// The form card. Fades and slides up after the header.
  final Widget card;

  /// Links under the card ("Register", "Back to Login", ...). Fades with the
  /// card.
  final Widget? footer;

  /// Gap between header and card.
  final double headerGap;

  /// Gap between card and footer.
  final double footerGap;

  /// When true the card is wrapped in [Expanded] and the column fills the
  /// screen, so the card's own contents can scroll inside a fixed frame.
  /// Register needs this; the others size to their content.
  final bool expandCard;

  const AuthEntrance({
    super.key,
    required this.header,
    required this.card,
    this.footer,
    this.headerGap = 24,
    this.footerGap = 12,
    this.expandCard = false,
  });

  @override
  State<AuthEntrance> createState() => _AuthEntranceState();
}

class _AuthEntranceState extends State<AuthEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _headerFade;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeIn),
    );
    _cardFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget animatedCard = FadeTransition(
      opacity: _cardFade,
      child: SlideTransition(position: _cardSlide, child: widget.card),
    );

    return Column(
      mainAxisSize: widget.expandCard ? MainAxisSize.max : MainAxisSize.min,
      children: [
        FadeTransition(opacity: _headerFade, child: widget.header),
        SizedBox(height: widget.headerGap),
        if (widget.expandCard) Expanded(child: animatedCard) else animatedCard,
        if (widget.footer != null) ...[
          SizedBox(height: widget.footerGap),
          FadeTransition(opacity: _cardFade, child: widget.footer!),
        ],
      ],
    );
  }
}
