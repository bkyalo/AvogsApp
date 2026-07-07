import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Reminds staff ~10 minutes before their shift's scheduled end time to
/// close out.
///
/// This is deliberately a single mechanism, not two: the reminder is
/// scheduled through the OS (so it fires as a real notification while the
/// app is backgrounded or closed), and configured to also present while
/// the app is in the foreground (so it reads as an in-app banner there).
/// Either way it's dismissible — the OS notification UI is swipe-to-dismiss
/// by design, so there's no extra "ignore" affordance to build.
class ShiftReminderService {
  ShiftReminderService._();

  static final ShiftReminderService instance = ShiftReminderService._();

  static const _reminderNotificationId = 9001;

  /// Payload carried on tap so app.dart knows where to navigate. Kept as a
  /// plain string (not a route object) since it has to survive being
  /// serialized by the OS notification system.
  static const shiftCloseTapPayload = 'shift_close_reminder';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Set by app.dart once the router exists. Called with
  /// [shiftCloseTapPayload] when the user taps the reminder — whether the
  /// app was already open, backgrounded, or gets cold-launched by the tap.
  void Function(String payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // Scheduling still works if this fails, just against UTC — the
      // reminder could fire at the wrong wall-clock time. Not fatal.
      developer.log('Could not resolve local timezone: $e', name: 'ShiftReminderService');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onNotificationTap?.call(payload);
      },
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// If the app process was not running and got cold-launched by tapping
  /// the reminder, this returns its payload so app.dart can navigate to
  /// Close Shop as soon as the router is ready. Returns null otherwise.
  Future<String?> consumeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  /// Schedules (or replaces) the shift-end reminder for [endTime] minus 10
  /// minutes. No-ops if that moment has already passed — e.g. a shift
  /// checked in with only a few minutes left on the clock.
  Future<void> scheduleShiftEndReminder({
    required DateTime endTime,
    required String shiftLabel,
  }) async {
    if (!_initialized) return;

    final fireAt = endTime.subtract(const Duration(minutes: 10));
    if (fireAt.isBefore(DateTime.now())) {
      await cancelShiftEndReminder();
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'shift_reminders',
      'Shift reminders',
      channelDescription:
          'Reminds staff to close out a shift near its scheduled end time.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      'Shift ending soon',
      '$shiftLabel shift ends in about 10 minutes — close out when ready.',
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Inexact is deliberate: it doesn't need the SCHEDULE_EXACT_ALARM
      // permission on Android, and a few minutes of slack on a "closing
      // reminder" is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: shiftCloseTapPayload,
    );
  }

  /// Cancels the pending reminder — called once a shift is actually closed
  /// (or reset), so a stale "closing time" notification doesn't fire after
  /// the fact.
  Future<void> cancelShiftEndReminder() async {
    if (!_initialized) return;
    await _plugin.cancel(_reminderNotificationId);
  }
}
