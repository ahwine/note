import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'notes_reminder_channel',
    'Pengingat Tugas',
    description: 'Notifikasi pengingat untuk tugas',
    importance: Importance.max,
  );

  static const MethodChannel _exactAlarmChannel =
      MethodChannel('notes_app/exact_alarm');

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {},
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackground,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);

    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await init();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications();

    if (canScheduleExact == false) {
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {
        await openExactAlarmSettings();
      }
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    await init();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    return await androidPlugin?.canScheduleExactNotifications() ??
        false;
  }

  static Future<void> openExactAlarmSettings() async {
    try {
      await _exactAlarmChannel.invokeMethod(
        'openExactAlarmSettings',
      );
    } catch (_) {}
  }

  static Future<bool> ensureExactAlarmAccess() async {
    await init();

    final allowed = await canScheduleExactAlarms();
    if (allowed) return true;

    await openExactAlarmSettings();
    return false;
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await init();

    if (!scheduledAt.isAfter(DateTime.now())) return;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ??
            false;

    const androidDetails = AndroidNotificationDetails(
      'notes_reminder_channel',
      'Pengingat Tugas',
      channelDescription: 'Notifikasi pengingat untuk tugas',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      details,
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: id.toString(),
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}