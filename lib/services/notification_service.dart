import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static final ValueNotifier<String?> openedTaskId = ValueNotifier<String?>(null);

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
    );

    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload != null) {
      _consumePayload(details!.notificationResponse!.payload!);
    }

    _initialized = true;
  }

  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      _consumePayload(response.payload!);
    }
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      _consumePayload(response.payload!);
    }
  }

  static void _consumePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['taskId'] != null) {
        openedTaskId.value = decoded['taskId'].toString();
        return;
      }
    } catch (_) {}

    if (payload.startsWith('task:')) {
      openedTaskId.value = payload.replaceFirst('task:', '');
    }
  }

  static Future<bool> requestPermissions() async {
    await init();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    return true;
  }

  static Future<bool> canScheduleExactAlarms() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  static Future<void> openExactAlarmSettings() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> cancelNotification(int id) async {
    await init();
    await _notifications.cancel(id);
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? taskId,
  }) async {
    await init();

    final payload = jsonEncode({'taskId': taskId});
    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminder notifications for tasks',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      details,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }
}
