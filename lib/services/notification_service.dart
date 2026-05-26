import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const _nativeChannel = MethodChannel('com.brian.beverage_inventory/notifications');

  NotificationService._init();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    // Default timezone
    tz.setLocalLocation(tz.getLocation('Africa/Harare'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap here if needed
      },
    );

    // Pre-create all notification channels on Android.
    // This is critical on Samsung/OEM devices: if we wait until the first
    // notification to create the channel, the OS may auto-create it with
    // 'Silent' importance. Explicit pre-creation locks in Importance.max.
    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'aura_sync_v3',
            'Aura Cloud Sync',
            description: 'Alerts when your sales are saved to the cloud',
            importance: Importance.max,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'aura_alerts',
            'Aura Alerts',
            description: 'Instant alerts and stock warnings',
            importance: Importance.max,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'aura_ai_insights',
            'Aura AI Insights',
            description: 'Daily reminders to check your stock and AI forecasts',
            importance: Importance.defaultImportance,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'aura_eod_summary',
            'Aura Daily Summary',
            description: 'End-of-day manager summary',
            importance: Importance.defaultImportance,
          ),
        );
        debugPrint('[NotificationService] All channels pre-created');
      }
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleDailyAITips() async {
    await flutterLocalNotificationsPlugin.cancelAll(); // Reset previous schedules

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'aura_ai_insights',
      'Aura AI Insights',
      channelDescription: 'Daily reminders to check your stock and AI forecasts',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    // Schedule for 9:00 AM every day
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0,
      title: '🤖 Daily AI Insights Ready',
      body: 'Time to check your stock! See how your inventory is moving and track your progress today.',
      scheduledDate: _nextInstanceOfTime(9, 0),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    
    // Also schedule an evening notification for end-of-day progress
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 1,
      title: '📊 End of Day Progress',
      body: 'Review your daily sales, identify peak trends, and prepare for tomorrow with Aura AI.',
      scheduledDate: _nextInstanceOfTime(18, 0), // 6:00 PM
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
  
  // Method to immediately show a notification
  Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'aura_alerts',
      'Aura Alerts',
      channelDescription: 'Instant alerts for stock level warnings',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      id: 888,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  /// Schedules a daily 8:00 PM reminder for managers to review the day's summary.
  Future<void> scheduleDailyManagerSummary() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'aura_eod_summary',
      'Aura Daily Summary',
      channelDescription: 'End-of-day manager summary reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 2,
      title: '📊 Daily Summary Ready',
      body: 'Tap to see today\'s sales performance.',
      scheduledDate: _nextInstanceOfTime(20, 0),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Shows an immediate cloud sync notification via native Android MethodChannel.
  /// Bypasses flutter_local_notifications entirely to avoid release-mode plugin issues.
  Future<void> showCloudSyncNotification(int count) async {
    debugPrint('[NotificationService] showCloudSyncNotification called (count=$count)');
    try {
      if (Platform.isAndroid) {
        final body = count == 1
            ? 'Your sale has been saved to the cloud.'
            : '$count sales have been saved to the cloud.';
        await _nativeChannel.invokeMethod('showNotification', {
          'id': 999,
          'title': '☁️ Synced to Cloud',
          'body': body,
          'channelId': 'aura_sync_v3',
        });
        debugPrint('[NotificationService] Native notification sent successfully');
      }
    } catch (e, stack) {
      debugPrint('[NotificationService] showCloudSyncNotification ERROR: $e\n$stack');
    }
  }

  /// Returns the importance level Samsung actually assigned to our cloud sync channel.
  /// Samsung sideloaded apps often get their channels downgraded to Importance.none (0)
  /// even if we request Importance.max (5). Returns -1 if not on Android or unavailable.
  Future<int> getCloudSyncChannelImportance() async {
    if (!Platform.isAndroid) return -1;
    try {
      final android = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return -1;
      final channels = await android.getNotificationChannels();
      final channel = channels?.firstWhere(
        (c) => c.id == 'aura_sync_v3',
        orElse: () => const AndroidNotificationChannel('', ''),
      );
      final importance = channel?.importance?.value ?? -1;
      debugPrint('[NotificationService] aura_sync_v2 channel importance=$importance');
      return importance;
    } catch (e) {
      debugPrint('[NotificationService] getCloudSyncChannelImportance error: $e');
      return -1;
    }
  }

  /// Shows an immediate end-of-day summary notification with real numbers.
  Future<void> showEndOfDaySummary({
    required double revenue,
    required int txCount,
    required double profit,
    required double margin,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'aura_eod_summary',
      'Aura Daily Summary',
      channelDescription: 'End-of-day manager summary reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id: 3,
      title: '📊 Today\'s Summary',
      body: '\$${revenue.toStringAsFixed(2)} revenue · $txCount sales · ${margin.toStringAsFixed(1)}% margin',
      notificationDetails: details,
    );
  }
}
