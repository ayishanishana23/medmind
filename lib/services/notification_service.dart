// lib/services/notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (kDebugMode) {
    print('Background notification tapped. payload: ${response.payload}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  /// Initialize local notifications + push notifications + Firestore listener
  Future<void> init() async {
    if (_inited) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    // Request notification permissions
    if (Platform.isIOS) {
      await _fln
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) await Permission.notification.request();
    }

    // Android channel
    const androidChannel = AndroidNotificationChannel(
      'med_channel',
      'Medicine reminders',
      description: 'Reminders to take medicine',
      importance: Importance.high,
    );
    final androidPlugin = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    // Initialization settings
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'MED_CAT',
          actions: [
            DarwinNotificationAction.plain('TAKEN', 'Taken'),
            DarwinNotificationAction.plain('MISSED', 'Missed'),
            DarwinNotificationAction.plain('SNOOZE', 'Snooze'),
          ],
        ),
      ],
    );

    await _fln.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // FCM setup
    await _initFirebaseMessaging();

    _inited = true;

    // Firestore real-time listener
    _listenToNotifications();

    if (kDebugMode) debugPrint('✅ NotificationService initialized');
  }

  /// Firebase Messaging setup
  Future<void> _initFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    if (Platform.isIOS) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }

    final token = await messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': token});
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showPushNotification(message);
    });

    if (kDebugMode) debugPrint('📱 FCM setup complete');
  }

  /// Show FCM notification manually
  Future<void> showPushNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      'med_channel',
      'Medicine reminders',
      channelDescription: 'Reminders to take medicine',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(categoryIdentifier: 'MED_CAT');

    await _fln.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );

    if (kDebugMode) debugPrint('🔔 FCM notification shown: ${notification.title}');
  }

  /// Background FCM handler
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    debugPrint('🔔 Handling background message: ${message.messageId}');
  }

  /// Firestore real-time listener for new notifications
  void _listenToNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final notificationId = data['notificationId'] as int?;
        if (notificationId == null) continue;

        if (change.type == DocumentChangeType.added && data['status'] == 'pending') {
          scheduleNotificationFromData(data);
        }

        if (change.type == DocumentChangeType.removed) {
          cancelNotificationById(notificationId);
        }
      }
    });
  }

  /// Schedule local notification from Firestore data
  Future<void> scheduleNotificationFromData(Map<String, dynamic> data) async {
    final id = data['notificationId'] as int;
    final medName = data['medName'] ?? '';
    final label = data['label'] ?? '';
    final beforeAfter = data['beforeAfter'] ?? '';
    final scheduledAt = (data['scheduledAt'] as Timestamp).toDate();

    final androidDetails = AndroidNotificationDetails(
      'med_channel',
      'Medicine reminders',
      channelDescription: 'Reminders to take medicine',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    final iosDetails = DarwinNotificationDetails(categoryIdentifier: 'MED_CAT');

    await _fln.zonedSchedule(
      id,
      '$label — $medName',
      '${beforeAfter.toLowerCase() == "before" ? "Before meal" : "After meal"} • Tap to mark',
      tz.TZDateTime.from(scheduledAt, tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(data),
    );

    if (kDebugMode) debugPrint('🕒 Scheduled local notification for $medName at $scheduledAt');
  }

  /// Schedule daily medicine reminder
  Future<int> scheduleDailyReminder({
    required String medId,
    required String medName,
    required String timeLabel,
    required String label,
    required String beforeAfter,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return -1;

    final schedule = _nextInstanceOf(timeLabel);
    final id = medId.hashCode ^ timeLabel.hashCode;

    final notifData = {
      'medicineId': medId,
      'medName': medName,
      'label': label,
      'beforeAfter': beforeAfter,
      'timeLabel': timeLabel,
      'scheduledAt': Timestamp.fromDate(schedule),
      'status': 'pending',
      'notificationId': id,
      'type': 'dose',
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(id.toString())
        .set(notifData);

    await scheduleNotificationFromData(notifData);

    return id;
  }

  /// Schedule snooze reminder
  Future<int> scheduleSnooze({
    required String medId,
    required String medName,
    required String timeLabel,
    required String label,
    required String beforeAfter,
    int minutes = 10,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return -1;

    final schedule = DateTime.now().add(Duration(minutes: minutes));
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;

    final notifData = {
      'medicineId': medId,
      'medName': medName,
      'label': label,
      'beforeAfter': beforeAfter,
      'timeLabel': timeLabel,
      'scheduledAt': Timestamp.fromDate(schedule),
      'status': 'snoozed',
      'notificationId': id,
      'type': 'snooze',
      'userId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(id.toString())
        .set(notifData);

    await scheduleNotificationFromData(notifData);

    return id;
  }

  /// Cancel a notification
  Future<void> cancelNotificationById(int id) async {
    await _fln.cancel(id);
    if (kDebugMode) debugPrint('❌ Cancelled notification $id');
  }

  /// Handle notification taps / actions
  Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (response.payload == null) return;

    final data = jsonDecode(response.payload!);
    final medId = data['medicineId']?.toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || medId == null) return;

    final actionId = (response.actionId ?? '').toUpperCase();
    String status = '';

    if (actionId == 'TAKEN') status = 'taken';
    else if (actionId == 'MISSED') status = 'missed';
    else if (actionId == 'SNOOZE') {
      status = 'snoozed';
      await scheduleSnooze(
        medId: medId,
        medName: data['medName'],
        timeLabel: data['timeLabel'],
        label: data['label'],
        beforeAfter: data['beforeAfter'],
        minutes: 10,
      );
    } else {
      status = 'opened';
    }

    await logDose(uid, medId, status, 'notification', medName: data['medName']);
  }

  /// Log medicine dose to Firestore
  Future<void> logDose(String uid, String medId, String status, String source, {required String? medName}) async {
    final medRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('medicines').doc(medId);
    final logRef = medRef.collection('logs').doc();

    await logRef.set({
      'medicineId': medId,
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
      'userId': uid,
      'source': source,
      'medName': medName,
    });

    if (status == 'taken') {
      try {
        await medRef.update({'stock': FieldValue.increment(-1)});
      } catch (e) {
        if (kDebugMode) debugPrint("⚠️ Failed to decrement stock: $e");
      }
    }
  }

  /// Helper: next DateTime from HH:mm
  DateTime _nextInstanceOf(String timeLabel) {
    try {
      final parts = timeLabel.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
      return scheduled.toLocal();
    } catch (_) {
      return DateTime.now().add(const Duration(seconds: 5));
    }
  }
}
