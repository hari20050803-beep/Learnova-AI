import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/study_reminder.dart';
import 'preferences_service.dart';

/// ---------------------------------------------------------------------------
/// NOTIFICATION SERVICE
/// Schedules local notifications for study reminders:
///   - one "remind before" notification
///   - one notification at the exact class / due / session time
/// Weekly classes and daily/weekly study sessions repeat automatically.
///
/// It also carries the one daily study suggestion. The suggestion itself is
/// not written here: the dashboard derives it from the student's own record
/// and hands it over, so the notification says the same thing the Academic
/// Health card says.
/// ---------------------------------------------------------------------------
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Notification id of the daily study suggestion.
  ///
  /// Reminder ids come from [StudyReminder.notifId] and its `+ 1`, which are
  /// derived from the Firestore document id; this constant sits far above that
  /// range so the suggestion can never collide with a reminder.
  static const int _kSuggestionId = 2000000001;

  /// Time of day at which the suggestion is delivered — early evening, when a
  /// student is most likely to be able to act on it.
  static const int _kSuggestionHour = 18;
  static const int _kSuggestionMinute = 0;

  bool _ready = false;

  /// Whether reminder notifications are turned on. Controlled by the toggle on
  /// the Profile / Settings screen. When off, scheduling is skipped (existing
  /// reminders keep their data; only the alarms are not set). Resets to on
  /// each app launch.
  final ValueNotifier<bool> notificationsEnabled = ValueNotifier<bool>(true);

  /// Called once at app start (from main.dart).
  Future<void> init() async {
    if (_ready) return;
    try {
      // Load timezone data and use the device's timezone, so reminders
      // fire at the right local time.
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Keep the default location if the device timezone is unknown.
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // iOS: permissions are asked later in requestPermissions(), not here.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      // Notifications are optional: the app must still work without them.
      _ready = false;
    }
  }

  /// Asks for notification permission the first time in this app session that
  /// the application actually wants to notify.
  ///
  /// The Reminders screen has always asked on entry, but the daily study
  /// suggestion needs no reminder to exist, so a student who never opened that
  /// screen would have had the suggestion scheduled and then silently dropped
  /// by the platform. Asking here closes that gap. Android shows its dialog
  /// only once whatever happens; the flag simply avoids pointless calls.
  bool _permissionAsked = false;

  Future<void> ensurePermission() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    await requestPermissions();
  }

  /// Asks the user for notification permission (Android 13+ and iOS).
  Future<void> requestPermissions() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();

      // iOS asks for alert / badge / sound permission at runtime.
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Ignore: user can still use reminders without notifications.
    }
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      'study_reminders',
      'Study Reminders',
      channelDescription: 'Reminders for classes, assignments and study time',
      importance: Importance.max,
      priority: Priority.high,
    ),
    // iOS: show the banner, badge and play a sound (incl. in foreground).
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  /// Whether the user still wants notifications for this reminder [kind].
  ///
  /// The kinds map 1:1 onto what the app actually schedules, so a switch that
  /// is off genuinely stops those notifications rather than only hiding a row.
  /// An unknown kind is allowed through — better a notification the user asked
  /// for than a silent drop.
  bool allowsKind(String kind) {
    final prefs = PreferencesService.instance;
    switch (kind) {
      case 'timetable':
      case 'study':
        return prefs.notifyStudySessions;
      case 'assignment':
        return prefs.notifyAssignments;
      case 'exam':
        return prefs.notifyExams;
      case 'suggestion':
        return prefs.notifyAiSuggestions;
      default:
        return true;
    }
  }

  /// Schedules the daily study suggestion, replacing yesterday's.
  ///
  /// [suggestion] is the line the dashboard is already showing on the Academic
  /// Health card, so the notification never says anything the application
  /// cannot justify from the student's own data. Passing an empty string
  /// cancels the notification, which is what happens when there is nothing
  /// worth saying.
  Future<void> scheduleDailySuggestion(String suggestion) async {
    if (!_ready) return;
    // Always clear the previous one first: the text changes as the student's
    // record changes, and a stale suggestion is worse than none.
    await cancelSuggestion();

    if (suggestion.trim().isEmpty) return;
    if (!notificationsEnabled.value) return;
    if (!allowsKind('suggestion')) return;

    // Without this the alarm is registered and the platform then discards the
    // notification, which looks exactly like a scheduling bug.
    await ensurePermission();

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _kSuggestionHour,
      _kSuggestionMinute,
    );
    // Past the hour already? Start from tomorrow.
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    await _schedule(
      id: _kSuggestionId,
      title: 'Your study suggestion',
      body: suggestion.trim(),
      when: when,
      // Repeats every day at the same time, with fresh text written each
      // time the dashboard is opened.
      match: DateTimeComponents.time,
    );
  }

  /// Removes the daily study suggestion.
  Future<void> cancelSuggestion() async {
    if (!_ready) return;
    await _plugin.cancel(id: _kSuggestionId);
  }

  /// Schedules the notifications for one reminder.
  /// Call after creating or editing a reminder.
  Future<void> scheduleForReminder(StudyReminder reminder) async {
    if (!_ready) return;
    // Editing first removes the old notifications.
    await cancelForReminder(reminder);
    // Respect the user's notification toggle (Profile / Settings).
    if (!notificationsEnabled.value) return;
    // ...and the per-category switches underneath it.
    if (!allowsKind(reminder.kind)) return;
    if (reminder.isCompleted || reminder.startAt == null) return;

    final DateTime? next = reminder.nextOccurrence();
    if (next == null) return;

    final tz.TZDateTime startTime = tz.TZDateTime.from(next, tz.local);

    // Which repeat mode?
    DateTimeComponents? match;
    if (reminder.repeat == 'weekly') {
      match = DateTimeComponents.dayOfWeekAndTime;
    } else if (reminder.repeat == 'daily') {
      match = DateTimeComponents.time;
    }

    // 1. The "remind before" notification.
    tz.TZDateTime beforeTime;
    if ((reminder.kind == 'assignment' || reminder.kind == 'exam') &&
        reminder.remindBefore == 0) {
      // "Same day" reminder = 8 AM on the due date.
      beforeTime = tz.TZDateTime(
        tz.local,
        startTime.year,
        startTime.month,
        startTime.day,
        8,
      );
    } else {
      beforeTime = startTime.subtract(Duration(minutes: reminder.remindBefore));
    }
    await _schedule(
      id: reminder.notifId,
      title: _beforeTitle(reminder),
      body: '${reminder.title} (${reminder.subject})',
      when: beforeTime,
      match: match,
    );

    // 2. The notification at the real class / due / session time.
    await _schedule(
      id: reminder.notifId + 1,
      title: _nowTitle(reminder),
      body: '${reminder.title} (${reminder.subject})',
      when: startTime,
      match: match,
    );
  }

  /// Removes the notifications of one reminder (delete / complete).
  Future<void> cancelForReminder(StudyReminder reminder) async {
    if (!_ready) return;
    await _plugin.cancel(id: reminder.notifId);
    await _plugin.cancel(id: reminder.notifId + 1);
  }

  /// Cancels every scheduled notification. Called when the user turns
  /// notifications off in Settings.
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Re-schedules alarms for a whole list of reminders. Called when the user
  /// turns notifications back on in Settings.
  ///
  /// Every reminder goes through [scheduleForReminder], which:
  ///   - cancels its old alarms by their stable ids first (no duplicates),
  ///   - skips completed reminders,
  ///   - skips expired one-time reminders (past due date),
  ///   - and re-schedules timetable / assignment / exam / study reminders,
  ///     repeating ones included.
  Future<void> rescheduleAll(List<StudyReminder> reminders) async {
    if (!_ready || !notificationsEnabled.value) return;
    for (final reminder in reminders) {
      await scheduleForReminder(reminder);
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    DateTimeComponents? match,
  }) async {
    // One-time notifications in the past are skipped. Repeating ones are
    // fine: the plugin moves them to the next matching day/time.
    if (match == null && when.isBefore(tz.TZDateTime.now(tz.local))) return;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: match,
      );
    } on PlatformException {
      // Exact alarms not allowed on this device: fall back to inexact
      // (may arrive a few minutes late, which is fine for reminders).
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: match,
      );
    }
  }

  String _beforeTitle(StudyReminder reminder) {
    switch (reminder.kind) {
      case 'timetable':
        return 'Class starting soon';
      case 'assignment':
        return 'Assignment due soon';
      case 'exam':
        return 'Exam coming up';
      default:
        return 'Study session soon';
    }
  }

  String _nowTitle(StudyReminder reminder) {
    switch (reminder.kind) {
      case 'timetable':
        return 'Class is starting now';
      case 'assignment':
        return 'Assignment is due now';
      case 'exam':
        return 'Exam time!';
      default:
        return 'Study session - time to focus!';
    }
  }
}
