import 'package:flutter/material.dart';

/// Which screen a dashboard card opens.
enum FeatureType {
  placeholder, // simple "coming soon" screen
  notes, // Notes Management (Firestore)
  chatbot, // AI Academic Chatbot (Gemini)
  summarizer, // AI Notes Summarizer (Gemini)
  quiz, // AI Quiz Generator (Gemini)
  flashcards, // AI Flashcards (Gemini)
  roadmap, // AI Study Roadmap (Gemini)
  progress, // Progress Dashboard (analytics)
  reminders, // Study Reminders (notifications + AI file reading)
  gpa, // GPA Calculator
  materials, // Study Materials (Firebase Storage + AI summary)
  settings, // Profile / Settings
}

/// ---------------------------------------------------------------------------
/// MODULE ACCENTS
/// Each feature carries its own two-colour accent. The accent is used ONLY on
/// small surfaces — icon tiles, progress bars, chips — never on card
/// backgrounds, so the app keeps its calm dark-navy base.
/// ---------------------------------------------------------------------------
class ModuleAccent {
  final Color start;
  final Color end;

  const ModuleAccent(this.start, this.end);

  LinearGradient get gradient => LinearGradient(
    colors: [start, end],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ----- The palette, one per module -----
  static const notes = ModuleAccent(Color(0xFFF59E0B), Color(0xFFFB923C));
  static const summarizer = ModuleAccent(Color(0xFF8B5CF6), Color(0xFFEC4899));
  static const quiz = ModuleAccent(Color(0xFFEC4899), Color(0xFFA855F7));
  static const flashcards = ModuleAccent(Color(0xFF06B6D4), Color(0xFF3B82F6));
  static const roadmap = ModuleAccent(Color(0xFF14B8A6), Color(0xFF22C55E));
  static const chatbot = ModuleAccent(Color(0xFF7C3AED), Color(0xFF06B6D4));
  static const gpa = ModuleAccent(Color(0xFF10B981), Color(0xFF059669));
  static const reminders = ModuleAccent(Color(0xFFEF4444), Color(0xFFF97316));
  static const progress = ModuleAccent(Color(0xFF3B82F6), Color(0xFF6366F1));
  static const materials = ModuleAccent(Color(0xFF0EA5E9), Color(0xFF6366F1));
  static const profile = ModuleAccent(Color(0xFF7C3AED), Color(0xFFA855F7));

  /// Study Hub's own accent (learning progress = green).
  static const studyHub = ModuleAccent(Color(0xFF22C55E), Color(0xFF14B8A6));

  /// Brand blue -> purple, used by Home.
  static const home = ModuleAccent(Color(0xFF3D5AF1), Color(0xFF7C3AED));
}

/// Hero tag shared by a Study Hub card's icon tile and the matching module
/// screen's header icon, so the tile flies between them.
///
/// Defined once here so the two ends can never drift apart.
String moduleHeroTag(FeatureType type) => 'module-hero-${type.name}';

/// ---------------------------------------------------------------------------
/// FEATURE MODEL (one entry per dashboard card)
/// ---------------------------------------------------------------------------
class Feature {
  final String title;
  final String description;
  final IconData icon;
  final FeatureType type;

  /// Accent used for this module's icon tile and highlights.
  final ModuleAccent accent;

  const Feature({
    required this.title,
    required this.description,
    required this.icon,
    this.type = FeatureType.placeholder,
    this.accent = ModuleAccent.home,
  });
}

/// All Learnova AI features shown on the dashboard.
const List<Feature> features = [
  Feature(
    title: 'Notes Management',
    description: 'Create, edit and organize your study notes.',
    icon: Icons.note_alt_rounded,
    type: FeatureType.notes,
    accent: ModuleAccent.notes,
  ),
  Feature(
    title: 'AI Notes Summarizer',
    description: 'Summarize long notes instantly with AI.',
    icon: Icons.auto_awesome_rounded,
    type: FeatureType.summarizer,
    accent: ModuleAccent.summarizer,
  ),
  Feature(
    title: 'AI Quiz Generator',
    description: 'Generate practice quizzes from your notes.',
    icon: Icons.quiz_rounded,
    type: FeatureType.quiz,
    accent: ModuleAccent.quiz,
  ),
  Feature(
    title: 'AI Flashcards',
    description: 'Generate flashcards and study with flip cards.',
    icon: Icons.style_rounded,
    type: FeatureType.flashcards,
    accent: ModuleAccent.flashcards,
  ),
  Feature(
    title: 'AI Study Roadmap',
    description: 'Get a personalized study plan for your exam.',
    icon: Icons.map_rounded,
    type: FeatureType.roadmap,
    accent: ModuleAccent.roadmap,
  ),
  Feature(
    title: 'AI Academic Chatbot',
    description: 'Ask study questions and get instant answers.',
    icon: Icons.chat_bubble_rounded,
    type: FeatureType.chatbot,
    accent: ModuleAccent.chatbot,
  ),
  Feature(
    title: 'GPA Calculator',
    description: 'Calculate your GPA and track your grades.',
    icon: Icons.calculate_rounded,
    type: FeatureType.gpa,
    accent: ModuleAccent.gpa,
  ),
  Feature(
    title: 'Study Reminders',
    description: 'Set reminders so you never miss study time.',
    icon: Icons.alarm_rounded,
    type: FeatureType.reminders,
    accent: ModuleAccent.reminders,
  ),
  Feature(
    title: 'Progress Dashboard',
    description: 'Track your learning progress visually.',
    icon: Icons.bar_chart_rounded,
    type: FeatureType.progress,
    accent: ModuleAccent.progress,
  ),
  Feature(
    title: 'Study Materials',
    description: 'Access and store your study materials.',
    icon: Icons.menu_book_rounded,
    type: FeatureType.materials,
    accent: ModuleAccent.materials,
  ),
  Feature(
    title: 'Profile / Settings',
    description: 'Manage your account, theme and settings.',
    icon: Icons.person_rounded,
    type: FeatureType.settings,
    accent: ModuleAccent.profile,
  ),
];
