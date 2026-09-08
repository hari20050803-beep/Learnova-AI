import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// PREFERENCES SERVICE
/// Saves small app settings on the device with shared_preferences so they
/// survive an app restart:
///   - dark mode on/off
///   - reminder notifications on/off (master switch)
///   - which KINDS of reminder may notify (classes / assignments / exams,
///     and the daily AI study suggestion)
/// If the storage can't be opened the app still works using the defaults.
///
/// The per-kind switches map onto the reminder kinds the app actually
/// schedules — 'timetable', 'study', 'assignment', 'exam' — plus the daily
/// suggestion the dashboard derives from the student's own record, so every
/// switch changes real behaviour. Nothing here invents a notification the app
/// cannot send.
/// ---------------------------------------------------------------------------
class PreferencesService {
  PreferencesService._();

  static final PreferencesService instance = PreferencesService._();

  static const String _kDarkMode = 'darkMode';
  static const String _kNotifications = 'notificationsEnabled';
  static const String _kNotifyStudy = 'notifyStudySessions';
  static const String _kNotifyAssignments = 'notifyAssignments';
  static const String _kNotifyExams = 'notifyExams';
  static const String _kNotifySuggestions = 'notifyAiSuggestions';

  SharedPreferences? _prefs;

  /// Opens the on-device storage. Call once at app start (from main.dart).
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Keep working with defaults if preferences can't be opened.
      _prefs = null;
    }
  }

  /// Saved dark-mode choice (defaults to light theme).
  bool get darkMode => _prefs?.getBool(_kDarkMode) ?? false;

  /// Master notifications switch (defaults to on).
  bool get notificationsEnabled => _prefs?.getBool(_kNotifications) ?? true;

  /// Classes and study sessions — reminder kinds 'timetable' and 'study'.
  bool get notifyStudySessions => _prefs?.getBool(_kNotifyStudy) ?? true;

  /// Assignment due dates — reminder kind 'assignment'.
  bool get notifyAssignments => _prefs?.getBool(_kNotifyAssignments) ?? true;

  /// Exam dates — reminder kind 'exam'.
  bool get notifyExams => _prefs?.getBool(_kNotifyExams) ?? true;

  /// The one daily study suggestion drawn from the student's own record
  /// (GPA, pending assignments, upcoming exams, quiz average).
  bool get notifyAiSuggestions => _prefs?.getBool(_kNotifySuggestions) ?? true;

  Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool(_kDarkMode, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs?.setBool(_kNotifications, value);
  }

  Future<void> setNotifyStudySessions(bool value) async {
    await _prefs?.setBool(_kNotifyStudy, value);
  }

  Future<void> setNotifyAssignments(bool value) async {
    await _prefs?.setBool(_kNotifyAssignments, value);
  }

  Future<void> setNotifyExams(bool value) async {
    await _prefs?.setBool(_kNotifyExams, value);
  }

  Future<void> setNotifyAiSuggestions(bool value) async {
    await _prefs?.setBool(_kNotifySuggestions, value);
  }
}
