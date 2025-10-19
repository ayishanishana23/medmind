import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  /// Simple initialization method like the working app
  Future<void> initNotification() async {
    tz.initializeTimeZones();
    
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  /// Initialize the notification service
  Future<bool> init() async {
    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      
      // Set local timezone
      try {
        final String timezoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timezoneName));
        debugPrint('✅ Local timezone set to: $timezoneName');
      } catch (e) {
        debugPrint('⚠️ Failed to get local timezone, using UTC: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Initialize the plugin
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Request permissions for Android 13+ and exact alarms
      await _requestPermissions();
      await _requestExactAlarmPermission();

      debugPrint('✅ NotificationService initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ NotificationService initialization error: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    return await _requestPermissions();
  }

  Future<bool> _requestPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        debugPrint('📱 Notification permission granted: $granted');
        return granted ?? false;
      }
      return true; // iOS permissions are handled during initialization
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Request exact alarm permission for Android 12+
  Future<bool> _requestExactAlarmPermission() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? canScheduleExactNotifications = await androidImplementation.canScheduleExactNotifications();
        debugPrint('📱 Can schedule exact notifications: $canScheduleExactNotifications');
        
        if (canScheduleExactNotifications == false) {
          debugPrint('⚠️ Exact alarm permission not granted - this is critical for Pixel devices!');
          debugPrint('💡 User needs to manually enable: Settings > Apps > MedMind > Special access > Alarms & reminders');
          
          final bool? granted = await androidImplementation.requestExactAlarmsPermission();
          debugPrint('📱 Exact alarm permission requested, granted: $granted');
          
          if (granted != true) {
            debugPrint('❌ CRITICAL: Exact alarm permission denied - scheduled notifications will not work reliably on this device');
          }
          
          return granted ?? false;
        }
        return canScheduleExactNotifications ?? false;
      }
      return true; // iOS doesn't need exact alarm permissions
    } catch (e) {
      debugPrint('❌ Error requesting exact alarm permissions: $e');
      debugPrint('💡 This might be a device-specific issue. Try manually enabling exact alarms in device settings.');
      return false;
    }
  }

  /// Check if notifications are allowed
  Future<bool> areNotificationsAllowed() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.areNotificationsEnabled();
        return granted ?? false;
      }
      return true; // Assume iOS permissions are granted
    } catch (e) {
      debugPrint('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  /// Check if exact alarms are allowed
  Future<bool> canScheduleExactAlarms() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? canSchedule = await androidImplementation.canScheduleExactNotifications();
        return canSchedule ?? false;
      }
      return true; // iOS doesn't need exact alarm permissions
    } catch (e) {
      debugPrint('❌ Error checking exact alarm permissions: $e');
      return false;
    }
  }

  /// Comprehensive device compatibility check for Pixel devices
  Future<Map<String, dynamic>> checkDeviceCompatibility() async {
    final results = <String, dynamic>{};
    
    try {
      // Basic permission checks
      results['notifications_enabled'] = await areNotificationsAllowed();
      results['exact_alarms_enabled'] = await canScheduleExactAlarms();
      
      // Check timezone setup
      results['timezone_name'] = tz.local.name;
      results['timezone_offset'] = tz.local.currentTimeZone.offset;
      
      // Check pending notifications count
      final pending = await getAllScheduledNotifications();
      results['pending_count'] = pending.length;
      
      // Device-specific warnings for Pixel 3a
      final warnings = <String>[];
      
      if (results['notifications_enabled'] != true) {
        warnings.add('Notifications are disabled - enable in Settings > Apps > MedMind > Notifications');
      }
      
      if (results['exact_alarms_enabled'] != true) {
        warnings.add('Exact alarms disabled - critical for Pixel devices. Enable in Settings > Apps > MedMind > Special access > Alarms & reminders');
      }
      
      // Add Pixel-specific warnings
      warnings.add('Pixel 3a users: Disable battery optimization in Settings > Apps > MedMind > Battery > Don\'t optimize');
      warnings.add('Check Do Not Disturb settings - may block notifications even with permissions');
      warnings.add('Ensure app is not in "Sleeping apps" list in device care settings');
      
      results['warnings'] = warnings;
      results['device_optimized'] = warnings.length <= 3; // Only generic warnings
      
      return results;
      
    } catch (e) {
      debugPrint('❌ Error checking device compatibility: $e');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Schedule daily medicine reminder notifications
  Future<void> scheduleDailyReminderForProfile({
    required String medId,
    required String medName,
    required String time, // Format: "HH:mm"
    required String label, // e.g., "Morning", "Evening"
    required String beforeAfter, // "Before" or "After"
    required String profileId,
    required String profileName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Check permissions first
      final notificationsAllowed = await areNotificationsAllowed();
      final exactAlarmsAllowed = await canScheduleExactAlarms();
      
      debugPrint('🔔 Scheduling notification for $medName at $time');
      debugPrint('📱 Notifications allowed: $notificationsAllowed');
      debugPrint('⏰ Exact alarms allowed: $exactAlarmsAllowed');
      
      if (!notificationsAllowed) {
        debugPrint('❌ Notifications not allowed, requesting permission...');
        await _requestPermissions();
      }
      
      if (!exactAlarmsAllowed) {
        debugPrint('❌ Exact alarms not allowed, requesting permission...');
        await _requestExactAlarmPermission();
      }

      // Parse time string to get hour and minute
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Create unique notification ID
      final notificationId = _generateNotificationId(medId, time);

      // Create notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medicine_reminders',
        'Medicine Reminders',
        channelDescription: 'Notifications for medicine taking times',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default.wav',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule daily notification from start date to end date
      DateTime currentDate = startDate;
      int dayCount = 0;
      int successCount = 0;
      
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        final scheduledDateTime = tz.TZDateTime(
          tz.local,
          currentDate.year,
          currentDate.month,
          currentDate.day,
          hour,
          minute,
        );

        // Only schedule if the time is in the future
        if (scheduledDateTime.isAfter(tz.TZDateTime.now(tz.local))) {
          try {
            // Choose schedule mode based on exact alarm permission
            // For Pixel devices, prefer exact modes for better reliability
            AndroidScheduleMode scheduleMode;
            if (exactAlarmsAllowed) {
              scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
            } else {
              debugPrint('⚠️ Using inexact mode - notifications may be delayed on Pixel devices');
              scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
            }
            
            debugPrint('📅 Scheduling for ${scheduledDateTime.toString()} with mode: $scheduleMode');
            debugPrint('🕐 Time until notification: ${scheduledDateTime.difference(tz.TZDateTime.now(tz.local)).inMinutes} minutes');
            
            await flutterLocalNotificationsPlugin.zonedSchedule(
              notificationId + dayCount, // Unique ID for each day
              '💊 Time for your medicine!',
              '$profileName, it\'s time to take $medName ($label - $beforeAfter meal)',
              scheduledDateTime,
              platformDetails,
              androidScheduleMode: scheduleMode,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              payload: 'medicine_reminder|$medId|$medName|$profileId|$profileName|$time|$label|$beforeAfter',
            );
            
            successCount++;
            debugPrint('✅ Scheduled notification ${notificationId + dayCount} for ${scheduledDateTime.toString()}');
            
            // Add a small delay between scheduling to avoid overwhelming the system
            await Future.delayed(const Duration(milliseconds: 10));
            
          } catch (e) {
            debugPrint('❌ Failed to schedule notification for ${scheduledDateTime.toString()}: $e');
            debugPrint('💡 This might be due to device restrictions or battery optimization');
          }
        } else {
          debugPrint('⏭️ Skipping past time: ${scheduledDateTime.toString()}');
        }

        currentDate = currentDate.add(const Duration(days: 1));
        dayCount++;
      }
      
      debugPrint('📊 Scheduling summary: $successCount/$dayCount notifications scheduled successfully');
      if (successCount < dayCount) {
        debugPrint('⚠️ Some notifications failed to schedule. Check device settings and permissions.');
      }

      if (successCount > 0) {
        debugPrint('✅ Scheduled $successCount daily reminders for $medName at $time ($label)');
      } else {
        debugPrint('❌ Failed to schedule any notifications for $medName');
        throw Exception('Failed to schedule notifications. Check device settings and permissions.');
      }
    } catch (e) {
      debugPrint('❌ Error scheduling daily reminder: $e');
      debugPrint('🔧 Troubleshooting tips:');
      debugPrint('   1. Check if notifications are enabled for this app');
      debugPrint('   2. Disable battery optimization for MedMind');
      debugPrint('   3. Enable exact alarms permission');
      debugPrint('   4. Check Do Not Disturb settings');
      rethrow;
    }
  }

  /// Schedule low stock notification
  Future<void> scheduleLowStockNotification({
    required String medId,
    required String medName,
    required String profileId,
    required String profileName,
    required int stockThreshold,
    int delaySeconds = 5,
  }) async {
    try {
      final notificationId = _generateLowStockNotificationId(medId);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'low_stock_alerts',
        'Low Stock Alerts',
        channelDescription: 'Notifications when medicine stock is running low',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default.wav',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));
      
      // Check permissions and choose appropriate schedule mode
      final exactAlarmsAllowed = await canScheduleExactAlarms();
      final scheduleMode = exactAlarmsAllowed 
          ? AndroidScheduleMode.exactAllowWhileIdle 
          : AndroidScheduleMode.inexactAllowWhileIdle;

      debugPrint('📅 Scheduling low stock alert for ${scheduledDate.toString()} with mode: $scheduleMode');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '⚠️ Low Stock Alert',
        '$profileName, your $medName is running low! Only $stockThreshold left.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'low_stock_alert|$medId|$medName|$profileId|$profileName|$stockThreshold',
      );

      debugPrint('✅ Scheduled low stock alert for $medName (threshold: $stockThreshold)');
    } catch (e) {
      debugPrint('❌ Error scheduling low stock notification: $e');
      rethrow;
    }
  }

  /// Show immediate notification for testing
  Future<void> showNotification(int id, String title, String body) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'main_channel',
        'Main Channel',
        channelDescription: 'Main notification channel',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default.wav',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
      );

      debugPrint('✅ Showed immediate notification: $title');
    } catch (e) {
      debugPrint('❌ Error showing immediate notification: $e');
    }
  }

  /// Show immediate notification (alternative method)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
    );
  }

  /// Cancel all notifications for a specific medicine
  Future<void> cancelMedicineNotifications(String medId) async {
    try {
      final pendingNotifications = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      
      for (final notification in pendingNotifications) {
        final payload = notification.payload;
        if (payload != null && payload.contains(medId)) {
          await flutterLocalNotificationsPlugin.cancel(notification.id);
          debugPrint('✅ Cancelled notification ${notification.id} for medicine $medId');
        }
      }
    } catch (e) {
      debugPrint('❌ Error cancelling medicine notifications: $e');
    }
  }

  /// Cancel low stock notification for a specific medicine
  Future<void> cancelLowStockNotification(String medId) async {
    try {
      final notificationId = _generateLowStockNotificationId(medId);
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      debugPrint('✅ Cancelled low stock notification for medicine $medId');
    } catch (e) {
      debugPrint('❌ Error cancelling low stock notification: $e');
    }
  }

  /// Get all scheduled notifications
  Future<List<PendingNotificationRequest>> getAllScheduledNotifications() async {
    try {
      return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting scheduled notifications: $e');
      return [];
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('✅ Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  /// Generate unique notification ID for medicine reminders
  int _generateNotificationId(String medId, String time) {
    final combined = '$medId-$time';
    return combined.hashCode.abs().remainder(2147483647);
  }

  /// Generate unique notification ID for low stock alerts
  int _generateLowStockNotificationId(String medId) {
    final combined = '$medId-lowstock';
    return combined.hashCode.abs().remainder(2147483647);
  }

  /// Simple schedule notification method similar to working app
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Notifications',
          channelDescription: 'Channel for scheduled notifications',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(
          sound: 'default.wav',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Set up notification listeners (for compatibility)
  static void setupListeners() {
    // Flutter Local Notifications handles listeners during initialization
    debugPrint('✅ Notification listeners setup complete');
  }

  /// Schedule a test notification at a specific time today (for testing purposes)
  Future<void> scheduleTestNotificationAtTime({
    required String time, // Format: "HH:mm"
    bool allowPastTime = false,
    String title = '🧪 Time-Based Test',
    String? body,
  }) async {
    try {
      final timeParts = time.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDateTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      
      // If time has passed and allowPastTime is false, schedule for tomorrow
      if (!allowPastTime && scheduledDateTime.isBefore(now)) {
        scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
      }
      
      body ??= 'Test notification scheduled for $time';
      
      const androidDetails = AndroidNotificationDetails(
        'test_time_channel',
        'Test Time Notifications',
        channelDescription: 'Time-based test notifications',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const platformDetails = NotificationDetails(android: androidDetails);
      
      final exactAlarmsAllowed = await canScheduleExactAlarms();
      final scheduleMode = exactAlarmsAllowed 
          ? AndroidScheduleMode.exactAllowWhileIdle 
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final testId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      final minutesUntil = scheduledDateTime.difference(now).inMinutes;
      
      debugPrint('🧪 Scheduling time-based test for ${scheduledDateTime.toString()}');
      debugPrint('⏰ Target time: $time');
      debugPrint('📱 Schedule mode: $scheduleMode');
      debugPrint('🕐 Time until notification: $minutesUntil minutes');
      debugPrint('📅 Date: ${scheduledDateTime.day == now.day ? "Today" : "Tomorrow"}');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        testId,
        title,
        body,
        scheduledDateTime,
        platformDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_time_notification|$testId|$time',
      );

      debugPrint('✅ Time-based test notification scheduled successfully (ID: $testId)');
    } catch (e) {
      debugPrint('❌ Failed to schedule time-based test notification: $e');
      rethrow;
    }
  }

  /// Schedule a test notification for X seconds from now (for testing purposes)
  Future<void> scheduleTestNotification({
    required int delaySeconds,
    String title = '🧪 Test Notification',
    String? body,
  }) async {
    try {
      final testId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));
      
      body ??= 'This test notification was scheduled for $delaySeconds seconds from now';
      
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Test notifications for debugging',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const platformDetails = NotificationDetails(android: androidDetails);
      
      // Check permissions and choose appropriate schedule mode
      final exactAlarmsAllowed = await canScheduleExactAlarms();
      final scheduleMode = exactAlarmsAllowed 
          ? AndroidScheduleMode.exactAllowWhileIdle 
          : AndroidScheduleMode.inexactAllowWhileIdle;

      debugPrint('🧪 Scheduling test notification for ${scheduledTime.toString()}');
      debugPrint('⏰ Delay: $delaySeconds seconds');
      debugPrint('📱 Schedule mode: $scheduleMode');
      debugPrint('🕐 Time until notification: ${scheduledTime.difference(tz.TZDateTime.now(tz.local)).inSeconds} seconds');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        testId,
        title,
        body,
        scheduledTime,
        platformDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_notification|$testId|$delaySeconds',
      );

      debugPrint('✅ Test notification scheduled successfully (ID: $testId)');
    } catch (e) {
      debugPrint('❌ Failed to schedule test notification: $e');
      rethrow;
    }
  }

  /// Print comprehensive troubleshooting guide for Pixel 3a
  static void printPixelTroubleshootingGuide() {
    debugPrint('\n' + '=' * 60);
    debugPrint('📱 PIXEL 3A NOTIFICATION TROUBLESHOOTING GUIDE');
    debugPrint('=' * 60);
    debugPrint('');
    debugPrint('🔧 CRITICAL SETTINGS TO CHECK:');
    debugPrint('');
    debugPrint('1. 📱 App Notifications:');
    debugPrint('   Settings > Apps > MedMind > Notifications');
    debugPrint('   → Enable "Show notifications"');
    debugPrint('   → Enable all notification categories');
    debugPrint('');
    debugPrint('2. ⏰ Exact Alarms (CRITICAL):');
    debugPrint('   Settings > Apps > Special access > Alarms & reminders');
    debugPrint('   → Find MedMind and enable "Allow setting alarms and reminders"');
    debugPrint('');
    debugPrint('3. 🔋 Battery Optimization:');
    debugPrint('   Settings > Apps > MedMind > Battery');
    debugPrint('   → Select "Don\'t optimize" or "Unrestricted"');
    debugPrint('');
    debugPrint('4. 🌙 Do Not Disturb:');
    debugPrint('   Settings > Sound > Do Not Disturb');
    debugPrint('   → Turn off or configure to allow MedMind notifications');
    debugPrint('');
    debugPrint('5. 💤 Sleeping Apps (if available):');
    debugPrint('   Settings > Device care > Battery > Background app limits');
    debugPrint('   → Remove MedMind from "Sleeping apps" or "Deep sleeping apps"');
    debugPrint('');
    debugPrint('6. 🔄 Additional Steps:');
    debugPrint('   → Restart the device after making changes');
    debugPrint('   → Clear MedMind app cache if issues persist');
    debugPrint('   → Ensure Android System WebView is updated');
    debugPrint('');
    debugPrint('⚠️  PIXEL-SPECIFIC ISSUES:');
    debugPrint('   → Pixel devices have aggressive battery management');
    debugPrint('   → Android\'s "Adaptive Battery" may interfere');
    debugPrint('   → Some notifications may be delayed by 5-15 minutes');
    debugPrint('');
    debugPrint('🧪 TESTING:');
    debugPrint('   → Use the diagnostic screen to test notifications');
    debugPrint('   → Schedule a test notification 1-2 minutes in the future');
    debugPrint('   → Check if immediate notifications work first');
    debugPrint('');
    debugPrint('=' * 60 + '\n');
  }
}
