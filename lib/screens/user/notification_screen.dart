// lib/screens/user/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  List<PendingNotificationRequest> _localNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadLocalNotifications();
  }

  Future<void> _loadLocalNotifications() async {
    final List<PendingNotificationRequest> pending =
    await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    setState(() {
      _localNotifications = pending;
    });
  }

  DateTime _parseScheduledAt(dynamic raw) {
    try {
      if (raw == null) return DateTime.now();
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) {
        final dt = DateTime.tryParse(raw);
        if (dt != null) return dt;
        final millis = int.tryParse(raw);
        if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (_) {}
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Notifications"),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            onPressed: _loadLocalNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadLocalNotifications(),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _localNotifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final firestoreDocs = snapshot.data?.docs ?? [];
            final firestoreNotifications = firestoreDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'type': 'firestore',
                'title': data['medName'] ?? 'Unknown Medicine',
                'subtitle':
                "${(data['beforeAfter'] ?? 'after').toString().toLowerCase() == 'before' ? 'Before meal' : 'After meal'}",
                'time': _parseScheduledAt(data['scheduledAt']),
              };
            }).toList();

            final localNotifications = _localNotifications.map((notif) {
              return {
                'type': 'local',
                'title': notif.title ?? 'Local Notification',
                'subtitle': notif.body ?? '',
                'time': DateTime.now(), // No scheduled time info available
              };
            }).toList();

            final allNotifications = [
              ...localNotifications,
              ...firestoreNotifications,
            ];

            // Sort by time descending
            allNotifications.sort((a, b) =>
                (b['time'] as DateTime).compareTo(a['time'] as DateTime));

            if (allNotifications.isEmpty) {
              return const Center(child: Text("No notifications yet"));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allNotifications.length,
              itemBuilder: (context, index) {
                final notif = allNotifications[index];
                final isLocal = notif['type'] == 'local';
                final title = notif['title'];
                final subtitle = notif['subtitle'];
                final time = notif['time'] as DateTime;

                return Card(
                  color: isLocal ? Colors.blue[50] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "$subtitle\n${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                    ),
                    trailing: Icon(
                      isLocal ? Icons.phone_android : Icons.cloud,
                      color: isLocal ? Colors.blue : Colors.green,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
