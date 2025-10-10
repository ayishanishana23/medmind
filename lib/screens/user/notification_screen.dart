import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/screens/user/user_home.dart';
import '../../core/constants.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
        leading: IconButton(onPressed: (){Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserHome()),
        );}, icon:Icon(Icons.arrow_back_ios) ),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final notifications = snapshot.data?.docs ?? [];
          if (notifications.isEmpty)
            return const Center(child: Text("No notifications yet"));

          // Sort by scheduledAt descending
          notifications.sort((a, b) {
            final aTime =
                (a['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime =
                (b['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final status = notif['status'] ?? 'pending';
              final medName = notif['medName'] ?? 'Unknown';
              final label = notif['label'] ?? '';
              final beforeAfter = notif['beforeAfter'] ?? '';
              final scheduledAt =
                  (notif['scheduledAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              final notificationId = notif['notificationId'] ?? 0;

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
                        "$medName - $label ",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${beforeAfter.toLowerCase() == 'before' ? 'Before meal' : 'After meal'} • Scheduled at ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}",
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
                                      await NotificationService().logDose(
                                        uid,
                                        notif['medicineId'],
                                        'taken',
                                        'notification',
                                        medName: medName,
                                      );
                                      await NotificationService()
                                          .cancelNotificationById(
                                            notificationId,
                                          );
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
                                      await NotificationService().logDose(
                                        uid,
                                        notif['medicineId'],
                                        'missed',
                                        'notification',
                                        medName: medName,
                                      );
                                      await NotificationService()
                                          .cancelNotificationById(
                                            notificationId,
                                          );
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
                                await NotificationService().scheduleSnooze(
                                  medId: notif['medicineId'],
                                  medName: medName,
                                  timeLabel: notif['timeLabel'],
                                  label: label,
                                  beforeAfter: beforeAfter,
                                  minutes: 10,
                                );
                                await NotificationService().logDose(
                                  uid,
                                  notif['medicineId'],
                                  'snoozed',
                                  'notification',
                                  medName: medName,
                                );
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
