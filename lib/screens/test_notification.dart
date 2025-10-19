import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class TestNotificationScreen extends StatelessWidget {
  const TestNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Notifications')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await NotificationService().init(); // ensure initialized

            await NotificationService().scheduleNotificationFromData({
              'notificationId': 1,
              'title': 'Test Reminder',
              'body': 'This is a test notification from scheduleNotificationFromData',
              'time': DateTime.now()
                  .add(const Duration(seconds: 10))
                  .toIso8601String(),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Test notification scheduled!')),
            );
          },
          child: const Text('Schedule Test Notification'),
        ),
      ),
    );
  }
}
