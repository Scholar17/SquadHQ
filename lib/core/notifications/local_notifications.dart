import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// A notification the phone itself fires later — no server, works offline.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.route,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// Where tapping it goes, e.g. "/match".
  final String route;
}

/// Android's on-device notifications: shows server pushes that arrive while
/// the app is open (FCM doesn't show those itself), and schedules match
/// reminders. A no-op until [init] succeeds — on web, in tests, or if the
/// plugin isn't available.
abstract final class LocalNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Squad updates from the server — also FCM's default channel (see
  /// AndroidManifest.xml), so background pushes land here too.
  static const _updates = AndroidNotificationChannel(
    'squad_updates',
    'Squad updates',
    description: 'New matches, RSVP nudges, Man of the Match and match fees',
    importance: Importance.high,
  );

  static const _reminders = AndroidNotificationChannel(
    'match_reminders',
    'Match reminders',
    description: 'A reminder 2 hours before matches you said In or Maybe to',
    importance: Importance.high,
  );

  /// Payload prefix marking scheduled match reminders, so they can be told
  /// apart from other pending notifications when re-syncing.
  static const _reminderPrefix = 'reminder:';

  static void Function(String route)? _onOpen;

  static Future<void> init({required void Function(String route) onOpen}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _onOpen = onOpen;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) => _open(response.payload),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_updates);
      await android?.createNotificationChannel(_reminders);
      _ready = true;

      // Opened the app by tapping a local notification.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _open(launch?.notificationResponse?.payload);
      }
    } catch (error) {
      debugPrint('LocalNotifications unavailable: $error');
    }
  }

  static void _open(String? payload) {
    if (payload == null) return;
    final route = payload.startsWith(_reminderPrefix)
        ? payload.substring(payload.indexOf('|') + 1)
        : payload;
    _onOpen?.call(route);
  }

  /// Android 13+ asks the user once; earlier versions are always allowed.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Shows a server push that arrived while the app was open.
  static Future<void> showUpdate({
    required String title,
    required String body,
    required String route,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      payload: route,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _updates.id,
          _updates.name,
          channelDescription: _updates.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Makes the pending match reminders exactly [reminders]: cancels ones no
  /// longer wanted (e.g. changed RSVP to Out, match cancelled) and
  /// (re)schedules the rest.
  static Future<void> syncReminders(List<ScheduledReminder> reminders) async {
    if (!_ready) return;
    final wanted = {for (final reminder in reminders) reminder.id};
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if ((pending.payload ?? '').startsWith(_reminderPrefix) && !wanted.contains(pending.id)) {
        await _plugin.cancel(id: pending.id);
      }
    }
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        title: reminder.title,
        body: reminder.body,
        payload: '$_reminderPrefix${reminder.id}|${reminder.route}',
        // Inexact: may land a few minutes late, but needs no "exact alarm"
        // permission from the user on Android 14+.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _reminders.id,
            _reminders.name,
            channelDescription: _reminders.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  /// Signing out: the next account shouldn't get this one's reminders.
  static Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }
}
