import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feature.dart';
import '../theme/app_colors.dart';
import 'chatbot_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'study_hub_screen.dart';

/// Room a scrollable tab must reserve at its bottom for the floating nav bar.
///
/// The shell sets `extendBody: true` so content scrolls behind the glass, which
/// means every scrollable tab has to reserve this much or its last item ends up
/// hidden under the bar. The system inset is handled separately by each
/// screen's own SafeArea.
///
/// 66 is the NavigationBar itself; the rest covers the margin that makes the
/// bar float clear of the screen edge. The bar occupies 66 + 10 + the system
/// inset, and each tab reserves this plus its own SafeArea inset, so there is
/// roughly 30 logical pixels of clearance on any device.
const double kBottomNavSpace = 84;

/// ---------------------------------------------------------------------------
/// MAIN SHELL
/// The four main sections of Learnova AI, behind one bottom navigation bar:
///   Home  ·  AI Chat  ·  Study Hub  ·  Profile
///
/// The sections live in a [PageView], so they can be swiped between as well as
/// tapped. The bar and the pages share one [PageController], which means the
/// indicator, label colour and accent all track a half-finished swipe instead
/// of only snapping at the end.
///
/// Each tab keeps its own state: PageView disposes off-screen children by
/// default, so every page is wrapped in [_KeepAlivePage]. Without it, swiping
/// away from AI Chat and back would throw away the open conversation — which
/// IndexedStack used to prevent.
/// ---------------------------------------------------------------------------
class MainShell extends StatefulWidget {
  /// Tab to open on first build (0 = Home).
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );

  late int _index = widget.initialIndex;

  /// Accent of the tab that is open, so the bar picks up each section's
  /// colour instead of always being indigo.
  static const List<ModuleAccent> _tabAccents = [
    ModuleAccent.home,
    ModuleAccent.chatbot,
    ModuleAccent.studyHub,
    ModuleAccent.profile,
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Lets the Home tab jump to another tab (e.g. its "Start Chat" button),
  /// and drives the bar's own taps.
  void _goToTab(int index) {
    if (index == _index) return;
    // The haptic fires from _onPageChanged so a tap and a swipe feel the same
    // and never double-buzz.
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
    // Home is kept alive and so does not rebuild on its own. Tell it to
    // re-read, or a GPA record or quiz result created in another tab would not
    // appear on the dashboard until the app was restarted.
    if (index == 0) {
      HomeScreen.refreshSignal.value++;
    }
  }

  /// Where the swipe currently is, as a fractional page. Used to blend the
  /// bar's accent mid-gesture. Falls back to the settled index before the
  /// controller has been attached to a viewport.
  double get _pageOffset {
    if (_pageController.hasClients && _pageController.position.haveDimensions) {
      return _pageController.page ?? _index.toDouble();
    }
    return _index.toDouble();
  }

  /// The accent for a fractional page position, blended between the two tabs
  /// a half-finished swipe sits between.
  ModuleAccent _accentAt(double page) {
    final int low = page.floor().clamp(0, _tabAccents.length - 1);
    final int high = page.ceil().clamp(0, _tabAccents.length - 1);
    if (low == high) return _tabAccents[low];
    final double t = page - low;
    return ModuleAccent(
      Color.lerp(_tabAccents[low].start, _tabAccents[high].start, t)!,
      Color.lerp(_tabAccents[low].end, _tabAccents[high].end, t)!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark(context);

    return Scaffold(
      // The bar is frosted, so let content scroll underneath it rather than
      // stopping above a solid strip.
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const _SnappyPageScrollPhysics(),
        // Start tracking from the moment the finger lands instead of after
        // the drag threshold — this is what removes the slight "catch" at the
        // start of a swipe and makes the page feel stuck to the thumb.
        dragStartBehavior: DragStartBehavior.down,
        // Builds the neighbouring page before it is reached, so the first
        // frame of a swipe is never blank. Costs nothing extra here: every
        // page is already kept alive.
        allowImplicitScrolling: true,
        children: [
          _KeepAlivePage(
            controller: _pageController,
            page: 0,
            child: HomeScreen(onOpenTab: _goToTab),
          ),
          _KeepAlivePage(
            controller: _pageController,
            page: 1,
            child: const ChatbotScreen(),
          ),
          _KeepAlivePage(
            controller: _pageController,
            page: 2,
            child: const StudyHubScreen(),
          ),
          _KeepAlivePage(
            controller: _pageController,
            page: 3,
            child: const SettingsScreen(),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        // Detaches the bar from the screen edges so it floats over the content
        // rather than sitting on it.
        //
        // The sides are 16, matching the horizontal padding every tab gives its
        // own list, so the ends of the bar line up with the edges of the cards
        // above it instead of sitting two pixels wider on each side.
        //
        // The whole system inset goes here, below the bar. It used to be split:
        // a third here and the rest as padding inside the glass, which left a
        // band of empty frosted panel under the labels and pushed the icons
        // above the centre of their own bar.
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          10 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          // Frosted glass: whatever scrolls past is blurred behind the bar.
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            // The bar's surface never changes during a swipe, so it is built
            // ONCE, outside the AnimatedBuilder. Only the theme below depends
            // on the accent — rebuilding this Container every frame would
            // re-run the blur needlessly.
            child: Container(
              decoration: BoxDecoration(
                // Translucent so the blur is visible, but opaque enough that
                // the labels stay readable over any content.
                color: AppColors.card(
                  context,
                ).withValues(alpha: isDark ? 0.72 : 0.78),
                // Deliberately rounder than a card: this is a floating pill,
                // and it has to match the ClipRRect above it.
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.65),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              // No SafeArea here on purpose. The inset is already applied as
              // margin below the bar, so adding it again inside would pad the
              // glass rather than lift it, which is what left the icons
              // floating above a strip of empty panel. The bar is now exactly
              // its own height and its contents sit centred in it.
              child: AnimatedBuilder(
                // Rebuilds as the swipe moves, so the accent blends
                // continuously instead of jumping when the page settles.
                animation: _pageController,
                builder: (context, _) {
                  final ModuleAccent accent = _accentAt(_pageOffset);
                  return NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: Colors.transparent,
                      indicatorColor: accent.end.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                      labelTextStyle: WidgetStateProperty.resolveWith(
                        (states) => TextStyle(
                          fontSize: 11.5,
                          fontWeight: states.contains(WidgetState.selected)
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: states.contains(WidgetState.selected)
                              ? accent.end
                              : AppColors.subText(context),
                        ),
                      ),
                      iconTheme: WidgetStateProperty.resolveWith(
                        (states) => IconThemeData(
                          size: 24,
                          color: states.contains(WidgetState.selected)
                              ? accent.end
                              : AppColors.subText(context),
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: _goToTab,
                      height: 66,
                      elevation: 0,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: [
                        _destination(
                          0,
                          Icons.home_outlined,
                          Icons.home_rounded,
                          'Home',
                        ),
                        _destination(
                          1,
                          Icons.smart_toy_outlined,
                          Icons.smart_toy_rounded,
                          'AI Chat',
                        ),
                        _destination(
                          2,
                          Icons.menu_book_outlined,
                          Icons.menu_book_rounded,
                          'Study Hub',
                        ),
                        _destination(
                          3,
                          Icons.person_outline_rounded,
                          Icons.person_rounded,
                          'Profile',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One bar destination whose selected icon grows as its page arrives.
  ///
  /// The scale is driven by distance from the current swipe position, so it
  /// lifts progressively during the gesture rather than popping at the end.
  NavigationDestination _destination(
    int page,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final double distance = (_pageOffset - page).abs().clamp(0.0, 1.0);
    final double scale = 1.0 + 0.18 * (1 - distance);
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Transform.scale(scale: scale, child: Icon(selectedIcon)),
      label: label,
    );
  }
}

/// Keeps a page alive while it is off-screen, and adds the parallax.
///
/// Two jobs in one wrapper because both need the same page index:
///   * [AutomaticKeepAliveClientMixin] stops PageView disposing the page, so
///     chats, scroll positions and half-typed text survive a swipe away.
///   * Each page drifts at a fraction of the swipe distance, which is what
///     gives the movement depth.
///
/// Translate only — no Opacity. A full-page Opacity forces a saveLayer on
/// every frame of the gesture, which on top of the frosted bar's
/// BackdropFilter is the difference between a smooth swipe and a stuttering
/// one. Transform is essentially free by comparison, and a slide with no fade
/// is what the Instagram/TikTok feel actually looks like.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  final PageController controller;
  final int page;

  const _KeepAlivePage({
    required this.child,
    required this.controller,
    required this.page,
  });

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by the keep-alive mixin
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        double delta = 0;
        if (widget.controller.hasClients &&
            widget.controller.position.haveDimensions) {
          delta =
              (widget.controller.page ?? widget.page.toDouble()) - widget.page;
        }
        final double clamped = delta.clamp(-1.0, 1.0);
        return Transform.translate(
          // Shifts each page a little way IN THE DIRECTION it is travelling,
          // partly cancelling the PageView's own 1:1 movement. The pages
          // therefore compress towards each other mid-swipe and separate as
          // one settles — subtle depth, symmetric in both directions.
          offset: Offset(clamped * 36, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Page physics tuned so a flick lands cleanly on the next tab.
///
/// Extends [PageScrollPhysics] so page snapping is kept, and overrides only
/// the settle spring. The ratio matters more than the raw numbers: at 1.0 the
/// spring is critically damped, so it arrives at the page and stops rather
/// than overshooting and wobbling back. Slightly stiffer than Flutter's
/// default (100) to shorten the settle without making it feel abrupt.
class _SnappyPageScrollPhysics extends PageScrollPhysics {
  const _SnappyPageScrollPhysics({super.parent});

  @override
  _SnappyPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPageScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 140, ratio: 1.0);
}
