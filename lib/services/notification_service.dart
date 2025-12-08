// lib/services/notification_service.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Stream to broadcast payloads when user taps a notification (used to navigate).
  // Other app parts can listen: NotificationService().onNotificationClick.listen(...)
  final StreamController<String?> _notificationClickStreamController =
  StreamController<String?>.broadcast();

  Stream<String?> get onNotificationClick => _notificationClickStreamController.stream;

  NotificationService._internal();

  /// Initialize timezone data quickly (call at app start)
  Future<void> _initTimezones() async {
    try {
      tz.initializeTimeZones();
      final String timezoneName = await FlutterTimezone.getLocalTimezone();

      // 🔥 Force Asia/Kolkata if anything fails or emulator reports UTC
      if (timezoneName.contains('UTC')) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        debugPrint('🕒 Timezone fallback: Asia/Kolkata');
      } else {
        tz.setLocalLocation(tz.getLocation(timezoneName));
        debugPrint('✅ Local timezone set to: $timezoneName');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get local timezone, using Asia/Kolkata fallback: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
  }


  /// Simple initialization method (kept for compatibility)
  Future<void> initNotification() async {
    await _initTimezones();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // initialize with tap handler
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      // onDidReceiveBackgroundNotificationResponse is available in newer versions if you need background routing
    );
  }

  /// Initialize the notification service (call once at app start).
  /// Returns true if initialization succeeded.
  Future<bool> init() async {
    try {
      await _initTimezones();

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

      // Initialize plugin with tap handler
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Create channels explicitly (Android 8+)
      await _createNotificationChannels();

      // Request runtime permissions when available
      await _requestPermissions();
      await _requestExactAlarmPermission();

      debugPrint('✅ NotificationService initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ NotificationService initialization error: $e');
      return false;
    }
  }

  Future<void> _createNotificationChannels() async {
    try {
      final androidPlatform = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlatform != null) {
        const medicineChannel = AndroidNotificationChannel(
          'medicine_reminders', // id
          'Medicine Reminders', // title
          description: 'Notifications for medicine taking times',
          importance: Importance.max,
          playSound: true,
        );

        const lowStockChannel = AndroidNotificationChannel(
          'low_stock_alerts',
          'Low Stock Alerts',
          description: 'Notifications when medicine stock is running low',
          importance: Importance.high,
          playSound: true,
        );

        await androidPlatform.createNotificationChannel(medicineChannel);
        await androidPlatform.createNotificationChannel(lowStockChannel);

        debugPrint('✅ Android channels created');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to create Android channels: $e');
    }
  }

  // -------------------- Permission helpers (kept) --------------------
  Future<bool> requestPermissions() async => await _requestPermissions();

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
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  Future<bool> _requestExactAlarmPermission() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? canScheduleExactNotifications = await androidImplementation.canScheduleExactNotifications();
        debugPrint('📱 Can schedule exact notifications: $canScheduleExactNotifications');

        if (canScheduleExactNotifications == false) {
          final bool? granted = await androidImplementation.requestExactAlarmsPermission();
          debugPrint('📱 Exact alarm permission requested, granted: $granted');
          return granted ?? false;
        }
        return canScheduleExactNotifications ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting exact alarm permissions: $e');
      return false;
    }
  }

  Future<bool> areNotificationsAllowed() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.areNotificationsEnabled();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? canSchedule = await androidImplementation.canScheduleExactNotifications();
        return canSchedule ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error checking exact alarm permissions: $e');
      return false;
    }
  }

  // -------------------- Notification click handling --------------------

  // This is called by the plugin when notification is tapped (foreground / background / terminated)
  void _handleNotificationResponse(NotificationResponse response) {
    try {
      final payload = response.payload;
      debugPrint('🔔 Notification tapped with payload: $payload');

      // Broadcast payload to app listeners
      _notificationClickStreamController.add(payload);
    } catch (e) {
      debugPrint('❌ Error handling notification response: $e');
    }
  }

  /// Call this to manually handle an incoming payload (if needed)
  void emitPayloadForTesting(String? payload) {
    _notificationClickStreamController.add(payload);
  }

  // -------------------- Scheduling helpers --------------------

  /// Schedule daily repeating medicine reminder that repeats until device-level cancel.
  /// Uses matchDateTimeComponents to repeat daily. It schedules the first occurrence at or after startDate.
  Future<void> scheduleDailyReminderForProfile({
    required String medId,
    required String medName,
    required String dosage,
    required String time, // "HH:mm"
    required String label, // "Morning", "Evening"
    required String beforeAfter, // "Before"/"After"
    required String profileId,
    required String profileName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    debugPrint("📝 Scheduling reminder for $medName ($label) for profile $profileName");

    // Ensure permissions & timezone set
    final allowed = await NotificationService().areNotificationsAllowed();
    debugPrint("🔔 Notifications allowed: $allowed");
    if (!allowed) await _requestPermissions();

    final exactAllowed = await NotificationService().canScheduleExactAlarms();
    debugPrint("⏱ Exact alarms allowed: $exactAllowed");
    if (!exactAllowed) await _requestExactAlarmPermission();

    final now = tz.TZDateTime.now(tz.local);

    // Parse HH:mm
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    debugPrint("⏰ Parsed time for $medName: $hour:$minute");

    // Unique ID per med + time + profile
    final notificationId = _generateNotificationId('$medId-$profileId', time);
    debugPrint("🆔 Notification ID: $notificationId");

    // Compute first notification time (tz aware)
    var firstNotification = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (firstNotification.isBefore(now)) {
      firstNotification = now.add(const Duration(seconds: 10));
      debugPrint("⏳ First notification was in the past today, scheduled immediately at $firstNotification");
    } else {
      debugPrint("📅 First notification set to $firstNotification");
    }

    final androidDetails = AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine taking times',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // ✅ Pipe-separated payload (compatible with parsePayload)
    final payload = 'medicine_reminder|$medId|$medName|$profileId|$profileName|$time|$label|$beforeAfter|$dosage';

    // ✅ Message includes dosage
    final bodyMessage = "$profileName, it’s time to take $medName ($dosage) — $label ($beforeAfter meal)";

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      '💊 Medicine Reminder',
      bodyMessage,
      firstNotification,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );

    debugPrint('✅ Scheduled daily reminder for $medName ($label) at $firstNotification');

    // Log pending notifications
    final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    debugPrint('📅 Pending notifications count after scheduling: ${pending.length}');
    for (var n in pending) {
      debugPrint('   🔹 Pending: ID=${n.id}, Title=${n.title}, Body=${n.body}, Payload=${n.payload}');
    }
  }



  /// Schedule snooze/reschedule for given minutes (one-shot)
  Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int minutesFromNow,
    required String profileId,
    required String profileName,
    String? originalPayload, // optional - include original data so you can link back
  }) async {
    // Compute the scheduled date in the correct timezone
    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesFromNow));

    // Unique notification ID using medId + timestamp
    final snoozeNotificationId = _generateNotificationId(
        '$medId-snooze-${DateTime.now().millisecondsSinceEpoch}',
        scheduledDate.toIso8601String());

    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'medicine_reminders', // channel id
      'Medicine Reminders', // channel name
      channelDescription: 'Notifications for medicine taking times',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    // Payload to link back to original medicine
    final payload = originalPayload ?? 'medicine_snooze|$medId|$medName|$profileId|$profileName|snoozed';

    // Schedule the snoozed notification
    await flutterLocalNotificationsPlugin.zonedSchedule(
      snoozeNotificationId,
      '💤 Snoozed: $medName',
      '$profileName, this is your snoozed reminder for $medName',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint('⏰ Snoozed $medName for $minutesFromNow minutes (ID: $snoozeNotificationId) at $scheduledDate');
  }

  /// Schedule low stock notification (kept as before)
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

      // choose schedule mode based on exact alarms permission when available
      final exactAlarmsAllowed = await canScheduleExactAlarms();
      final scheduleMode = exactAlarmsAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

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

  /// Cancel all notifications for a specific medicine (payload contains medId)
  Future<void> cancelMedicineNotifications(String medId, String profileId) async {
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

  Future<void> cancelLowStockNotification(String medId) async {
    try {
      final notificationId = _generateLowStockNotificationId(medId);
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      debugPrint('✅ Cancelled low stock notification for medicine $medId');
    } catch (e) {
      debugPrint('❌ Error cancelling low stock notification: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getAllScheduledNotifications() async {
    try {
      return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting scheduled notifications: $e');
      return [];
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('✅ Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  int _generateNotificationId(String medId, String time) {
    final combined = 'reminder-$medId-$time';
    return combined.hashCode.abs().remainder(2147483647);
  }

  int _generateLowStockNotificationId(String medId) {
    final combined = 'lowstock-$medId-lowstock';
    return combined.hashCode.abs().remainder(2147483647);
  }

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

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  static void setupListeners() {
    debugPrint('✅ Notification listeners setup complete (use NotificationService().onNotificationClick to listen)');
  }

  Future<void> scheduleTestNotificationAtTime({
    required String time,
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

      final testId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      final minutesUntil = scheduledDateTime.difference(now).inMinutes;

      debugPrint('🧪 Scheduling time-based test for ${scheduledDateTime.toString()}');
      debugPrint('⏰ Target time: $time');
      debugPrint('📱 Schedule mode: (auto)');
      debugPrint('🕐 Time until notification: $minutesUntil minutes');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        testId,
        title,
        body,
        scheduledDateTime,
        platformDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_time_notification|$testId|$time',
      );

      debugPrint('✅ Time-based test notification scheduled successfully (ID: $testId)');
    } catch (e) {
      debugPrint('❌ Failed to schedule time-based test notification: $e');
      rethrow;
    }
  }

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

      await flutterLocalNotificationsPlugin.zonedSchedule(
        testId,
        title,
        body,
        scheduledTime,
        platformDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_notification|$testId|$delaySeconds',
      );

      debugPrint('✅ Test notification scheduled successfully (ID: $testId)');
    } catch (e) {
      debugPrint('❌ Failed to schedule test notification: $e');
      rethrow;
    }
  }

  // 🔹 Get the initial payload when app launched from a notification
  static Future<String?> getInitialNotificationPayload() async {
    final plugin = NotificationService().flutterLocalNotificationsPlugin;
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }


  static void printPixelTroubleshootingGuide() {
    debugPrint('\n' + '=' * 60);
    debugPrint('📱 PIXEL 3A NOTIFICATION TROUBLESHOOTING GUIDE');
    debugPrint('=' * 60);
    debugPrint('🔧 CRITICAL SETTINGS TO CHECK:');
    debugPrint('1. App Notifications: Settings > Apps > MedMind > Notifications');
    debugPrint('2. Exact Alarms (Special access) > allow for MedMind');
    debugPrint('3. Battery Optimization > Don\'t optimize / Unrestricted');
    debugPrint('4. Do Not Disturb > allow app notifications');
    debugPrint('5. Remove app from Sleeping apps / Background restrictions');
    debugPrint('=' * 60 + '\n');
  }

  /// Parse notification payload into a structured Map
  /// Supports payload format like:
  /// 'medicine_reminder|medId|medName|profileId|profileName|time|label|beforeAfter'
  static Map<String, String?> parsePayload(String payload) {
    final parts = payload.split('|');
    if (parts.isEmpty) return {};

    final type = parts[0];
    switch (type) {
      case 'medicine_reminder':
        if (parts.length < 9) return {}; // updated to include dosage
        return {
          'type': type,
          'medId': parts[1],
          'medName': parts[2],
          'profileId': parts[3],
          'profileName': parts[4],
          'time': parts[5],
          'label': parts[6],
          'beforeAfter': parts[7],
          'dosage': parts[8], // added dosage
        };

      case 'low_stock_alert':
        if (parts.length < 6) return {};
        return {
          'type': type,
          'medId': parts[1],
          'medName': parts[2],
          'profileId': parts[3],
          'profileName': parts[4],
          'stockThreshold': parts[5],
        };

      case 'test_notification':
      case 'test_time_notification':
        return {'type': type};

      default:
        return {'type': 'unknown'};
    }
  }




  Future<void> logDose(String medId, bool taken, {String? profileId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    // 1️⃣ Reference to the medicine document
    DocumentReference medRef;
    if (profileId != null && profileId.isNotEmpty && profileId != 'self') {
      medRef = firestore
          .collection('users')
          .doc(uid)
          .collection('profiles')
          .doc(profileId)
          .collection('medicines')
          .doc(medId);
    } else {
      medRef = firestore
          .collection('users')
          .doc(uid)
          .collection('medicines')
          .doc(medId);
    }

    // 2️⃣ Create a new log document
    final logRef = medRef.collection('logs').doc();

    try {
      // Create log entry first
      await logRef.set({
        'taken': taken,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'notification',
      });

      developer.log('✅ Dose log written for $medId (taken=$taken)', name: 'NotificationService');

      // 3️⃣ If taken, reduce stock using transaction
      if (taken) {
        await firestore.runTransaction((txn) async {
          final snap = await txn.get(medRef);
          if (!snap.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'not-found',
              message: 'Medicine document not found for $medId',
            );
          }

          final data = snap.data() as Map<String, dynamic>? ?? {};
          int currentStock = 0;
          String stockFieldName = 'stock';

          // Detect which stock field your docs have
          if (data.containsKey('stock')) {
            stockFieldName = 'stock';
            currentStock = data['stock'] is int
                ? data['stock']
                : int.tryParse('${data['stock']}') ?? 0;
          } else if (data.containsKey('remainingStock')) {
            stockFieldName = 'remainingStock';
            currentStock = data['remainingStock'] is int
                ? data['remainingStock']
                : int.tryParse('${data['remainingStock']}') ?? 0;
          } else if (data.containsKey('quantity')) {
            stockFieldName = 'quantity';
            currentStock = data['quantity'] is int
                ? data['quantity']
                : int.tryParse('${data['quantity']}') ?? 0;
          }

          final newStock = currentStock > 0 ? currentStock - 1 : 0;
          txn.update(medRef, {stockFieldName: newStock});

          developer.log(
            '🔽 Decremented $stockFieldName: $currentStock -> $newStock for $medId',
            name: 'NotificationService',
          );
        });

        // 4️⃣ After transaction, fetch updated medicine and check for low stock
        final updatedSnap = await medRef.get();
        final medData = updatedSnap.data() as Map<String, dynamic>? ?? {};
        final medName = medData['name'] ?? 'Unknown Medicine';
        final currentStock = medData['stock'] ?? 0;
        final lowStockLimit = medData['lowStockAlert'] ?? 0;

        // Check and trigger alert
        if (currentStock <= lowStockLimit) {
          developer.log('⚠️ Low stock detected for $medName: $currentStock ≤ $lowStockLimit',
              name: 'NotificationService');

          // Add Firestore alert document
          await firestore
              .collection('users')
              .doc(uid)
              .collection('stockAlerts')
              .add({
            'medicineId': medId,
            'medicineName': medName,
            'currentStock': currentStock,
            'alertType': 'low_stock',
            'timestamp': FieldValue.serverTimestamp(),
            'seen': false,
          });

          // Send local notification alert
          await showInstantNotification(
            title: 'Low Stock Alert',
            body: '$medName stock is running low ($currentStock left). Please restock soon!',
          );
        }
      }
    } on FirebaseException catch (fe) {
      developer.log('❌ Firestore error in logDose: ${fe.code} ${fe.message}',
          name: 'NotificationService', error: fe);
      rethrow;
    } catch (e, st) {
      developer.log('❌ Unexpected error in logDose: $e',
          name: 'NotificationService', error: e, stackTrace: st);
      rethrow;
    }
  }
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'low_stock_channel',
      'Low Stock Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, details);
  }




}
