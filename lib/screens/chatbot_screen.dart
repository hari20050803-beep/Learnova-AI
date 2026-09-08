import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/feature.dart';
import '../services/gemini_service.dart';
import '../services/history_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_date.dart';
import '../widgets/accent_icon.dart';
import '../widgets/animations.dart';
import '../widgets/empty_state.dart';
import '../widgets/focus_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_header.dart';
import '../widgets/press_scale.dart';

/// The AI Chat module's own accent (violet -> cyan), matching the tab bar.
const ModuleAccent _accent = ModuleAccent.chatbot;

/// Accent text stays readable on both themes: lightened on dark backgrounds.
Color _accentOn(BuildContext context, Color color) =>
    AppColors.isDark(context) ? Color.lerp(color, Colors.white, 0.45)! : color;

/// [_accent]'s gradient as a const, so the AppBar's flexibleSpace can be one.
const LinearGradient _accentGradient = LinearGradient(
  colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// ---------------------------------------------------------------------------
/// AI ACADEMIC CHATBOT (powered by Gemini) - ChatGPT style
/// Every conversation is its own session in Firestore:
///   users/{uid}/chat_sessions/{sessionId}/messages
/// The drawer on the right shows all chats with search, pin and delete.
///
/// The welcome screen, bubbles and input bar are presentation only — the
/// message list handed to Gemini is unchanged.
/// ---------------------------------------------------------------------------
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  static const ChatMessage _welcomeMessage = ChatMessage(
    text:
        'Hi! I am Learnova AI, your study assistant. '
        'Ask me any academic question!',
    isUser: false,
  );

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Messages of the chat that is open right now.
  List<ChatMessage> _messages = [_welcomeMessage];

  /// The open session (null = a brand new, not yet saved chat).
  ChatSession? _currentSession;

  /// All saved sessions (shown in the drawer).
  List<ChatSession> _sessions = [];

  bool _isLoading = false; // Gemini thinking
  bool _isLoadingSessions = true; // drawer list loading
  bool _isLoadingMessages = false; // opening an old chat
  String _search = '';

  /// True while the input has something to send — drives the send button's
  /// active/idle animation.
  bool _canSend = false;

  /// A brand new chat that only holds the greeting. Used to show the welcome
  /// screen instead of a lone bubble — [_messages] itself is untouched, so
  /// the history sent to Gemini is exactly the same either way.
  bool get _isFreshChat =>
      _currentSession == null &&
      _messages.length == 1 &&
      !_messages.first.isUser;

  /// Drives the welcome orb's breathing.
  late final AnimationController _orbController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // Rebuild only when the button should flip between idle and active,
    // not on every keystroke.
    _inputController.addListener(() {
      final bool canSend = _inputController.text.trim().isNotEmpty;
      if (canSend != _canSend) setState(() => _canSend = canSend);
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    _inputController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // HELPERS
  // -----------------------------------------------------------------------

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Drawer list after search filter, pinned chats first.
  List<ChatSession> get _visibleSessions {
    final String query = _search.trim().toLowerCase();
    final list = query.isEmpty
        ? List.of(_sessions)
        : _sessions
              .where((s) => s.title.toLowerCase().contains(query))
              .toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  // -----------------------------------------------------------------------
  // SESSION ACTIONS
  // -----------------------------------------------------------------------

  Future<void> _loadSessions() async {
    try {
      final sessions = await HistoryService.instance.loadChatSessions();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  /// Starts a fresh, empty chat (saved only when a message is sent).
  void _newChat() {
    setState(() {
      _currentSession = null;
      _messages = [_welcomeMessage];
    });
  }

  /// Opens a previous chat from the drawer.
  Future<void> _openSession(ChatSession session) async {
    Navigator.of(context).pop(); // close the drawer
    setState(() {
      _currentSession = session;
      _messages = [];
      _isLoadingMessages = true;
    });

    try {
      final messages = await HistoryService.instance.loadSessionMessages(
        session.id,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _togglePin(ChatSession session) async {
    try {
      await HistoryService.instance.setSessionPinned(
        session.id,
        !session.isPinned,
      );
      if (!mounted) return;
      setState(() {
        _sessions = _sessions
            .map(
              (s) => s.id == session.id ? s.copyWith(isPinned: !s.isPinned) : s,
            )
            .toList();
      });
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text(
          '"${session.title}" and all its messages will be deleted. '
          'This cannot be undone.',
        ),
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
      await HistoryService.instance.deleteChatSession(session.id);
      if (!mounted) return;
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
        // If the open chat was deleted, start a new one.
        if (_currentSession?.id == session.id) {
          _currentSession = null;
          _messages = [_welcomeMessage];
        }
      });
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  // -----------------------------------------------------------------------
  // SENDING MESSAGES
  // -----------------------------------------------------------------------

  /// Saves one message into the current session (errors do not block chat).
  Future<void> _saveMessage(ChatMessage message) async {
    final session = _currentSession;
    if (session == null) return;
    try {
      await HistoryService.instance.saveSessionMessage(session.id, message);
    } on HistoryException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _sendMessage() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = ChatMessage(text: text, isUser: true);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    // The first message creates the session. Its title is the message
    // text (shortened), like ChatGPT does.
    if (_currentSession == null) {
      try {
        final String title = text.length > 35
            ? '${text.substring(0, 35)}...'
            : text;
        final session = await HistoryService.instance.createChatSession(title);
        if (!mounted) return;
        setState(() {
          _currentSession = session;
          _sessions.insert(0, session);
        });
      } on HistoryException catch (e) {
        if (mounted) _showError(e.message);
      }
    }

    // Save the question to Firestore.
    _saveMessage(userMessage);

    try {
      // Real Gemini call with the full conversation history.
      final String answer = await GeminiService.instance.askChatbot(_messages);

      if (!mounted) return;
      final aiMessage = ChatMessage(text: answer, isUser: false);
      setState(() {
        _messages.add(aiMessage);
        // Move the open chat to the top of the list (latest activity).
        if (_currentSession != null) {
          _sessions = _sessions
              .map(
                (s) => s.id == _currentSession!.id
                    ? s.copyWith(updatedAt: DateTime.now())
                    : s,
              )
              .toList();
        }
      });
      _scrollToBottom();

      // Save the answer to Firestore.
      _saveMessage(aiMessage);
    } on GeminiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Centred with a tighter type scale — the default left-aligned title
        // drifted away from the two actions and left the bar looking lopsided.
        centerTitle: true,
        titleSpacing: 0,
        title: const Text(
          'AI Academic Chatbot',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        // The module's own gradient instead of the flat brand indigo, so the
        // header matches the accent used throughout this screen.
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _accentGradient),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_rounded),
            onPressed: _newChat,
          ),
          IconButton(
            tooltip: 'Chat history',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          // Balances the leading edge so the centred title sits truly centred.
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: _buildHistoryDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            // ----- Messages -----
            Expanded(
              // Cross-fades between the spinner, the welcome screen and the
              // conversation, so switching never snaps into place.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _isLoadingMessages
                    ? const Center(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(
                          color: AppColors.indigo,
                        ),
                      )
                    : _isFreshChat
                    ? _welcomeView()
                    : ListView.builder(
                        // The key makes the switcher animate when the open
                        // chat changes.
                        key: ValueKey(_currentSession?.id ?? 'new'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          // The extra item at the end is the typing indicator.
                          if (index == _messages.length) {
                            return const _TypingBubble();
                          }
                          // Each bubble gently fades + slides in (newest
                          // message animates as it is added).
                          return FadeSlideIn(
                            duration: const Duration(milliseconds: 280),
                            slideFraction: 0.08,
                            child: _ChatBubble(message: _messages[index]),
                          );
                        },
                      ),
              ),
            ),

            // ----- Input row -----
            //
            // No clearance is added here for the floating nav bar, and none is
            // added inside the composer either. The Scaffold sets extendBody,
            // which makes it report the bar's height as bottom padding to the
            // body, so the SafeArea above has already reserved that space.
            //
            // Adding kBottomNavSpace as well — which is what this screen used
            // to do, inside the composer's own padding — counted the bar twice:
            // once as a tall band of composer surface under the typing field,
            // and again as the gap the SafeArea had already left.
            _inputBar(),
          ],
        ),
      ),
    );
  }

  // ----- Welcome screen (a brand new chat) -----

  /// Shown instead of a lone greeting bubble. Purely presentational: the
  /// greeting still lives in [_messages] and still goes to Gemini as history.
  Widget _welcomeView() {
    final bool isDark = AppColors.isDark(context);

    return LayoutBuilder(
      key: const ValueKey('welcome'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Breathing assistant orb.
                  FadeSlideIn(child: _breathingOrb(isDark)),
                  const SizedBox(height: 26),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 70),
                    child: Text(
                      'Learnova AI',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 130),
                    child: Padding(
                      // Held narrower than the card below so the sentence wraps
                      // to a readable measure instead of the full width.
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _welcomeMessage.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: AppColors.subText(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 190),
                    child: _capabilities(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The assistant mark, breathing.
  ///
  /// One controller driving scale and glow together, so the orb reads as
  /// alive rather than as a spinner. 3.2s is deliberately slow — fast enough
  /// to notice, slow enough to ignore while reading.
  Widget _breathingOrb(bool isDark) {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_orbController.value);
        return Transform.scale(
          scale: 0.96 + 0.08 * t,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: _accent.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.end.withValues(
                    alpha: (isDark ? 0.42 : 0.28) + 0.18 * t,
                  ),
                  blurRadius: 26 + 22 * t,
                  spreadRadius: 1 + 3 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 42),
    );
  }

  /// What the assistant is good at. Plain text, not shortcuts — the student
  /// still types their own question.
  Widget _capabilities() {
    const items = <(IconData, String)>[
      (Icons.help_outline_rounded, 'Ask academic questions'),
      (Icons.lightbulb_outline_rounded, 'Explain difficult topics'),
      (Icons.edit_note_rounded, 'Help you plan your studies'),
    ];

    return GlassCard(
      blur: 0,
      elevated: true,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, item) in items.indexed)
            // Each line arrives just after the one above it, so the card
            // assembles rather than appearing all at once.
            FadeSlideIn(
              delay: Duration(milliseconds: 240 + i * 90),
              slideFraction: 0.20,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    // A tinted tile rather than a bare glyph — gives the icon
                    // a consistent optical width so the labels align.
                    AccentIcon(icon: item.$1, color: _accent.end, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ----- Input bar -----

  /// The composer sits on its own raised surface, so the conversation reads
  /// as scrolling underneath it.
  Widget _inputBar() {
    final bool isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // Even padding on all four sides, and 16 at the sides to match every
      // other screen. The nav bar clearance is applied by the caller.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // The field sits in its own rounded surface so the composer reads as
          // one pill rather than a boxed input floating on a bar.
          Expanded(
            child: FocusField(
              accent: _accent.end,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.09)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: TextField(
                  controller: _inputController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Ask a study question...',
                    // The surface above draws the shape, so the field itself
                    // must not draw its own fill or border.
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(6, 14, 16, 14),
                    prefixIcon: Icon(
                      Icons.school_outlined,
                      size: 21,
                      color: _accentOn(context, _accent.end),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _sendButton(),
        ],
      ),
    );
  }

  /// Send button. It grows and lights up once there is something to send,
  /// dims while idle, and swaps the arrow for a spinner while Gemini answers.
  Widget _sendButton() {
    final bool active = _canSend && !_isLoading;

    return PressScale(
      onTap: _sendMessage,
      child: AnimatedScale(
        scale: active ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: active ? 1.0 : 0.55,
          duration: const Duration(milliseconds: 220),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: _accent.gradient,
              shape: BoxShape.circle,
              // The glow only appears when the button is ready to send.
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _accent.end.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : const [],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('sending'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      key: ValueKey('idle'),
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// The right-side drawer with search + all saved chats.
  Widget _buildHistoryDrawer(BuildContext context) {
    final visible = _visibleSessions;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: GradientHeader(
                icon: Icons.forum_rounded,
                title: 'Your Chats',
                subtitle:
                    '${_sessions.length} conversation${_sessions.length == 1 ? '' : 's'}',
                accent: _accent,
              ),
            ),

            // ----- Search bar -----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
              ),
            ),

            // ----- New chat button -----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GradientButton(
                text: '+  New Chat',
                onPressed: () {
                  Navigator.of(context).pop(); // close drawer
                  _newChat();
                },
              ),
            ),

            // ----- Sessions list -----
            Expanded(
              child: _isLoadingSessions
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.indigo),
                    )
                  : visible.isEmpty
                  ? (_search.isEmpty
                        ? EmptyState(
                            icon: Icons.forum_rounded,
                            title: 'No chats yet',
                            message: 'Start a new conversation!',
                            accent: _accent.end,
                          )
                        : EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            message: 'No chats match your search.',
                            accent: _accent.end,
                          ))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final session = visible[index];
                        final bool isOpen = session.id == _currentSession?.id;

                        return FadeSlideIn(
                          delay: Duration(
                            milliseconds: 25 * (index.clamp(0, 8)),
                          ),
                          child: _sessionTile(session, isOpen),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// One saved chat, as a rounded card. The open chat is marked with an
  /// accent border and tint so it is obvious which one you are in.
  Widget _sessionTile(ChatSession session, bool isOpen) {
    final bool isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOpen
            ? _accent.end.withValues(alpha: isDark ? 0.16 : 0.09)
            : AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen
              ? _accent.end.withValues(alpha: 0.55)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
          width: isOpen ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSession(session),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (session.isPinned ? AppColors.purple : _accent.end)
                        .withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    session.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.chat_bubble_outline_rounded,
                    color: _accentOn(
                      context,
                      session.isPinned ? AppColors.purple : _accent.end,
                    ),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDateTime(session.updatedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.subText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Chat options',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.subText(context),
                    size: 20,
                  ),
                  onSelected: (action) {
                    if (action == 'pin') _togglePin(session);
                    if (action == 'delete') _deleteSession(session);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            session.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            size: 18,
                            color: AppColors.indigo,
                          ),
                          const SizedBox(width: 8),
                          Text(session.isPinned ? 'Unpin' : 'Pin'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular assistant mark shown beside every AI reply.
class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: _accent.gradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _accent.end.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 17),
    );
  }
}

/// One chat bubble (user = accent gradient on the right, AI = card on the
/// left with the assistant mark beside it).
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;

    final Widget bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        gradient: isUser ? _accent.gradient : null,
        color: isUser ? null : AppColors.card(context),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        boxShadow: AppColors.cardShadow(context),
        border: isUser ? null : AppColors.cardBorder(context),
      ),
      child: SelectableText(
        message.text,
        style: TextStyle(
          color: isUser ? Colors.white : AppColors.text(context),
          fontSize: 14.5,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isUser
            ? [Flexible(child: bubble)]
            : [
                const _AiAvatar(),
                const SizedBox(width: 8),
                Flexible(child: bubble),
              ],
      ),
    );
  }
}

/// Small "Thinking..." bubble shown while Gemini answers.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          // Grows in from the bottom-left corner, like a bubble being blown.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              alignment: Alignment.bottomLeft,
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: AppColors.cardShadow(context),
                border: AppColors.cardBorder(context),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TypingDots(color: _accentOn(context, _accent.end)),
                  const SizedBox(width: 10),
                  Text(
                    'Thinking...',
                    style: TextStyle(color: AppColors.subText(context)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
