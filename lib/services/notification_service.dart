// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (kDebugMode) print('[notificationTapBackground] payload: ${response.payload}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _inited = false;
  Timer? _missCheckerTimer;

  /// Initialize notifications, request permissions, and start listeners
  Future<void> init() async {
    if (_inited) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    // Request permissions
    if (Platform.isIOS) {
      await _fln
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
      }
      if (status.isGranted) {
        if (kDebugMode) debugPrint("✅ Notification permission granted (Android)");
      } else {
        if (kDebugMode) debugPrint("🚫 Notification permission denied (Android)");
      }
    }

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'med_channel',
      'Medicine reminders',
      description: 'Reminders to take medicine',
      importance: Importance.high,
    );

    final androidPlugin = _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    // Initialize plugin
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

    // Start listeners
    _listenToNotifications();
    await _markMissedOnInit();
    _startPeriodicMissChecker();

    _inited = true;

    if (kDebugMode) {
      debugPrint('✅ NotificationService initialized');
      debugPrint('ℹ️ Tip for Vivo devices: Enable Autostart and set battery to "No restrictions" '
          'under Settings → Apps → MedMind → Battery → No restriction + Autostart ON');
    }
  }

  /// Firestore listener
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
          final enriched = Map<String, dynamic>.from(data);
          enriched['_docId'] = change.doc.id;
          scheduleNotificationFromData(enriched);
        }

        if (change.type == DocumentChangeType.removed) {
          cancelNotificationById(notificationId);
        }
      }
    });
  }

  /// Schedule local notification from Firestore data
  Future<void> scheduleNotificationFromData(Map<String, dynamic> data) async {
    try {
      if (!_inited) await init();

      if (Platform.isAndroid) {
        var status = await Permission.notification.status;
        if (!status.isGranted) {
          status = await Permission.notification.request();
          if (!status.isGranted) {
            debugPrint("🚫 Notification permission denied – skipping schedule");
            return;
          }
        }
      }

      final id = (data['notificationId'] is int)
          ? data['notificationId'] as int
          : DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final medName = data['medName'] ?? '';
      final type = data['type'] ?? 'dose';
      final label = data['label'] ?? '';
      final beforeAfter = data['beforeAfter'] ?? '';

      DateTime scheduledDateTime;
      final rawScheduled = data['scheduledAt'];
      if (rawScheduled is Timestamp) {
        scheduledDateTime = rawScheduled.toDate();
      } else if (data['time'] is String && (data['time'] as String).isNotEmpty) {
        scheduledDateTime = _nextInstanceOf(data['time'] as String);
      } else {
        scheduledDateTime = DateTime.now().add(const Duration(seconds: 5));
      }

      if (scheduledDateTime.isBefore(DateTime.now())) {
        debugPrint("⚠️ Skipping past notification for $scheduledDateTime");
        return;
      }

      // Sync to Firestore
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final docId = data['_docId']?.toString();
        if (uid != null && docId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .doc(docId)
              .update({'scheduledAt': Timestamp.fromDate(scheduledDateTime)});
        }
      } catch (_) {}

      const androidDetails = AndroidNotificationDetails(
        'med_channel',
        'Medicine reminders',
        channelDescription: 'Reminders to take medicine',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails(categoryIdentifier: 'MED_CAT');

      final title = (data['title'] as String?) ??
          (type == 'low_stock' ? 'Low Stock Alert' : '$label — $medName');

      String body = data['body'] as String? ?? '';
      if (body.isEmpty) {
        if (type == 'dose') {
          body =
          '${beforeAfter.toLowerCase() == "before" ? "Before meal" : "After meal"} • Tap to mark';
        } else if (type == 'low_stock') {
          body = 'Your medicine "$medName" is running low';
        } else if (type == 'snooze') {
          body = 'Snoozed reminder for $medName';
        }
      }

      final tzSchedule = tz.TZDateTime.from(scheduledDateTime, tz.local);
      final payload =
      jsonEncode({...data, '_scheduledAt': tzSchedule.toIso8601String()});

      await _fln.zonedSchedule(
        id,
        title,
        body,
        tzSchedule,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('✅ Scheduled local notification: id=$id "$title" at $scheduledDateTime');
    } catch (e, st) {
      debugPrint('❌ scheduleNotificationFromData failed: $e\n$st');
    }
  }

  /// Cancel notification
  Future<void> cancelNotificationById(int id, {bool removeDoc = false}) async {
    try {
      await _fln.cancel(id);
      if (kDebugMode) debugPrint('❌ Cancelled local notification $id');

      if (removeDoc) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .doc(id.toString());
          final doc = await docRef.get();
          if (doc.exists) await docRef.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ cancelNotificationById failed: $e');
    }
  }

  /// Daily reminder
  Future<void> scheduleDailyReminderForProfile({
    required String medId,
    required String medName,
    required String time,
    required String label,
    required String beforeAfter,
    required String profileId,
    required String profileName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final scheduleDate = _nextInstanceOf(time);
    final notifId = (medId + label + profileId).hashCode % 1000000;

    final notifData = {
      'medicineId': medId,
      'medName': medName,
      'label': label,
      'beforeAfter': beforeAfter,
      'time': time,
      'scheduledAt': Timestamp.fromDate(scheduleDate),
      'status': 'pending',
      'notificationId': notifId,
      'type': 'dose',
      'userId': uid,
      'profileId': profileId,
      'profileName': profileName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId.toString())
        .set(notifData);

    await scheduleNotificationFromData(notifData);
  }

  /// Snooze reminder
  Future<int> scheduleSnooze({
    required String medId,
    required String medName,
    required String time,
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
      'time': time,
      'scheduledAt': Timestamp.fromDate(schedule),
      'status': 'pending',
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

  /// Low stock alert
  Future<void> scheduleLowStockNotification({
    required String medId,
    required String medName,
    required String profileId,
    required String profileName,
    required int stockThreshold,
    int delaySeconds = 5,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final notifId = medId.hashCode ^ 9999;
    final scheduled = DateTime.now().add(Duration(seconds: delaySeconds));

    final notifData = {
      'medicineId': medId,
      'medName': medName,
      'title': 'Low Stock Alert',
      'body': 'Your medicine "$medName" is running low (≤ $stockThreshold left)',
      'notificationId': notifId,
      'status': 'pending',
      'type': 'low_stock',
      'userId': uid,
      'profileId': profileId,
      'profileName': profileName,
      'createdAt': FieldValue.serverTimestamp(),
      'scheduledAt': Timestamp.fromDate(scheduled),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId.toString())
        .set(notifData);

    await scheduleNotificationFromData(notifData);
  }

  /// Log dose
  Future<void> logDose(String uid, String medId, String status, String source,
      {required String? medName, String? profileId}) async {
    final medRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc(medId);
    final logRef = medRef.collection('logs').doc();

    await logRef.set({
      'medicineId': medId,
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
      'userId': uid,
      'source': source,
      'medName': medName,
      'profileId': profileId,
    });
  }

  /// Notification response handler
  Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (response.payload == null) return;

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.payload!) as Map<String, dynamic>;
    } catch (_) {}

    final medId = data['medicineId']?.toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || medId == null) return;

    final actionId = (response.actionId ?? '').toUpperCase();

    if (actionId == 'TAKEN') {
      await _handleTaken(uid, medId, data);
    } else if (actionId == 'MISSED') {
      await _handleMissed(uid, medId, data);
    } else if (actionId == 'SNOOZE') {
      await scheduleSnooze(
        medId: medId,
        medName: data['medName'] ?? '',
        time: data['time'] ?? '',
        label: data['label'] ?? '',
        beforeAfter: data['beforeAfter'] ?? '',
        minutes: 10,
      );
    }

    // Cancel notification
    try {
      final nid = data['notificationId'] as int?;
      if (nid != null) await _fln.cancel(nid);
    } catch (_) {}
  }

  Future<void> _handleTaken(String uid, String medId, Map<String, dynamic> data) async {
    await logDose(uid, medId, 'taken', 'notification',
        medName: data['medName'], profileId: data['profileId']?.toString());

    final medRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicines')
        .doc(medId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(medRef);
        if (!snap.exists) return;
        final current = (snap.data()?['stock'] as num?)?.toInt() ?? 0;
        final lowAlert = (snap.data()?['lowStockAlert'] as num?)?.toInt() ?? 0;
        final newStock = (current > 0) ? current - 1 : 0;
        tx.update(medRef, {'stock': newStock});

        if (newStock <= lowAlert && newStock > 0) {
          await scheduleLowStockNotification(
            medId: medId,
            medName: data['medName'] ?? '',
            profileId: data['profileId']?.toString() ?? 'self',
            profileName: data['profileName']?.toString() ?? 'Self',
            stockThreshold: lowAlert,
          );
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Stock decrement failed: $e');
    }

    try {
      final nid = data['notificationId'] as int?;
      if (nid != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(nid.toString());
        final doc = await docRef.get();
        if (doc.exists) {
          await docRef.update({'status': 'responded', 'respondedAt': FieldValue.serverTimestamp()});
        }
      }
    } catch (_) {}
  }

  Future<void> _handleMissed(String uid, String medId, Map<String, dynamic> data) async {
    await logDose(uid, medId, 'missed', 'notification',
        medName: data['medName'], profileId: data['profileId']?.toString());
    try {
      final nid = data['notificationId'] as int?;
      if (nid != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(nid.toString());
        final doc = await docRef.get();
        if (doc.exists) {
          await docRef.update({'status': 'missed', 'respondedAt': FieldValue.serverTimestamp()});
        }
      }
    } catch (_) {}
  }

  /// Periodic missed check
  void _startPeriodicMissChecker() {
    _missCheckerTimer?.cancel();
    _missCheckerTimer = Timer.periodic(const Duration(seconds: 60), (_) => _markMissedReminders());
  }

  Future<void> _markMissedOnInit() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await _markMissedReminders();
  }

  Future<void> _markMissedReminders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('status', isEqualTo: 'pending')
          .where('type', isEqualTo: 'dose')
          .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      for (final doc in q.docs) {
        final data = doc.data();
        final nid = data['notificationId'] as int?;
        final medId = data['medicineId']?.toString();
        if (nid == null || medId == null) continue;

        await doc.reference.update({'status': 'missed', 'respondedAt': FieldValue.serverTimestamp()});
        await logDose(uid, medId, 'missed', 'system', medName: data['medName'], profileId: data['profileId']?.toString());

        try {
          await _fln.cancel(nid);
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ markMissedReminders error: $e');
    }
  }

  /// Compute next DateTime from "HH:mm"
  DateTime _nextInstanceOf(String time) {
    try {
      final parts = time.split(':');
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

  /// Test notification helper
  Future<void> showTestNotification() async {
    final id = DateTime.now().millisecondsSinceEpoch % 1000000;
    await _fln.show(
      id,
      'Test Notification',
      'This is a test medicine reminder',
      NotificationDetails(
        android: AndroidNotificationDetails('med_channel', 'Medicine reminders'),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'test': true}),
    );
  }

  void dispose() => _missCheckerTimer?.cancel();
}
