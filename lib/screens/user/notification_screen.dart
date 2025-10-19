// lib/screens/user/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/screens/user/user_home.dart';
import '../../core/constants.dart';


class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  DateTime _parseScheduledAt(dynamic raw) {
    try {
      if (raw == null) return DateTime.now();
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) {
        // Try ISO parse
        final dt = DateTime.tryParse(raw);
        if (dt != null) return dt;
        // Try parse as millis string
        final millis = int.tryParse(raw);
        if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (_) {}
    return DateTime.now();
  }

  int? _parseNotificationId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
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
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserHome()),
            );
          },
          icon: const Icon(Icons.arrow_back_ios),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text("No notifications yet"));

          // Convert QueryDocumentSnapshot -> Map<String, dynamic> safely
          final notifications = docs.map((doc) {
            final Map<String, dynamic> data = {};
            try {
              final raw = doc.data();
              if (raw is Map<String, dynamic>) data.addAll(raw);
            } catch (_) {}
            data['_docId'] = doc.id;
            return data;
          }).toList();

          // Sort by scheduledAt descending (safe parsing)
          notifications.sort((a, b) {
            final aTime = _parseScheduledAt(a['scheduledAt']);
            final bTime = _parseScheduledAt(b['scheduledAt']);
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];

              final status = (notif['status'] ?? 'pending').toString();
              final medName = notif['medName']?.toString() ?? 'Unknown';
              final label = notif['label']?.toString() ?? '';
              final beforeAfter = notif['beforeAfter']?.toString() ?? '';
              final scheduledAt = _parseScheduledAt(notif['scheduledAt']);
              final notificationId = _parseNotificationId(notif['notificationId']) ?? 0;
              final medicineId = notif['medicineId']?.toString() ?? '';

              // Friendly scheduled time text (if we were unable to parse we show N/A)
              String scheduledTimeText;
              try {
                scheduledTimeText =
                "${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}";
              } catch (_) {
                scheduledTimeText = "N/A";
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$medName${label.isNotEmpty ? ' - $label' : ''}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${beforeAfter.toLowerCase() == 'before' ? 'Before meal' : 'After meal'} • Scheduled at $scheduledTimeText",
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: status == 'taken'
                                  ? null
                                  : () async {
                                // mark as taken and cancel local notif
                                // await NotificationService().logDose(
                                //   uid,
                                //   medicineId,
                                //   'taken',
                                //   'notification',
                                //   medName: medName,
                                // );
                                // if (notificationId != 0) {
                                //   await NotificationService()
                                //       .cancelNotificationById(notificationId);
                                // }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const FittedBox(child: Text("Taken")),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: status == 'missed'
                                  ? null
                                  : () async {
                                // await NotificationService().logDose(
                                //   uid,
                                //   medicineId,
                                //   'missed',
                                //   'notification',
                                //   medName: medName,
                                // );
                                // if (notificationId != 0) {
                                //   await NotificationService()
                                //       .cancelNotificationById(notificationId);
                                // }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const FittedBox(child: Text("Missed")),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: () async {
                                final timeLabel = notif['timeLabel']?.toString() ?? '';
                                // await NotificationService().scheduleSnooze(
                                //   medId: medicineId,
                                //   medName: medName,
                                //   time: timeLabel,
                                //   label: label,
                                //   beforeAfter: beforeAfter,
                                //   minutes: 10,
                                // );
                                // await NotificationService().logDose(
                                //   uid,
                                //   medicineId,
                                //   'snoozed',
                                //   'notification',
                                //   medName: medName,
                                // );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: const FittedBox(child: Text("Snooze")),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
