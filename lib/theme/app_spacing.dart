import 'package:flutter/widgets.dart';

/// ---------------------------------------------------------------------------
/// SPACING AND SHAPE
///
/// One scale for the whole application, so a card on the Study Hub sits the
/// same distance from the edge as a card on Profile, and a gap between two
/// sections is the same gap everywhere.
///
/// Before this existed the screens had drifted: page padding ranged from 12 to
/// 24, cards used eight different corner radii, and the gaps between elements
/// included 2, 3, 5, 7, 26 and 36. Nothing was wrong on its own; together they
/// made screens feel as though they came from different applications.
///
/// Everything here is a multiple of four. Nothing here touches colour,
/// typography or animation — those are in [AppColors] and [AppTheme] and are
/// deliberately left alone.
/// ---------------------------------------------------------------------------
class AppSpacing {
  const AppSpacing._();

  // ---- Gaps -------------------------------------------------------------
  // Named for how far apart two things feel, not for their value, so a screen
  // reads as "related items" rather than "eight pixels".

  /// Between parts of one element — an icon and its label.
  static const double xs = 4;

  /// Between tightly related lines, such as a title and its subtitle.
  static const double sm = 8;

  /// Between items in a list or a row of chips.
  static const double md = 12;

  /// The standard gap: between cards, and between a heading and its content.
  static const double lg = 16;

  /// Between one section and the next.
  static const double xl = 24;

  /// Above a major heading that starts a new part of the screen.
  static const double xxl = 32;

  // ---- Page --------------------------------------------------------------

  /// Distance from the side of the screen to the content on every screen.
  ///
  /// The four main tabs already used this; the detail screens did not, which
  /// is why content used to shift sideways when one was opened.
  static const double page = 16;

  /// Padding inside a card, between its border and its content.
  static const double card = 16;

  /// Padding inside a compact card or tile.
  static const double cardTight = 12;

  // ---- Shape -------------------------------------------------------------

  /// Corner radius of a card or a panel.
  static const double radius = 20;

  /// Corner radius of something small sitting inside a card — a chip, an
  /// icon tile, an input.
  static const double radiusSm = 14;

  /// Corner radius of a full-width button.
  static const double radiusButton = 16;

  // ---- Components --------------------------------------------------------

  /// Height of a primary button. Matches the height the gradient button and
  /// the text fields already used, so rows of them line up.
  static const double buttonHeight = 52;

  /// The ordinary icon, beside a label or in a list row.
  static const double icon = 20;

  /// An icon that is the subject rather than the decoration — a leading icon
  /// in a card header.
  static const double iconLg = 24;

  /// An icon inside a chip or a dense row.
  static const double iconSm = 16;

  // ---- Ready-made insets -------------------------------------------------

  /// Standard padding inside a card.
  static const EdgeInsets cardPadding = EdgeInsets.all(card);

  /// Standard side padding for a screen's scrolling content. Callers add
  /// their own top and bottom, because the bottom has to clear the floating
  /// navigation bar on the four main tabs and does not on the others.
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: page,
  );
}
