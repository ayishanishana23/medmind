import 'package:flutter/material.dart';
import '../screens/notification_test_screen.dart';
import '../services/notification_service.dart';

class DebugMenu {
  /// Show debug menu with notification testing options
  static void showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🔧 Debug Menu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationTestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('Notification Diagnostics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                NotificationService.printPixelTroubleshootingGuide();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Troubleshooting guide printed to console'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('Print Troubleshooting Guide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final notificationService = NotificationService();
                try {
                  await notificationService.showNotification(
                    DateTime.now().millisecondsSinceEpoch.remainder(100000),
                    '🧪 Quick Test',
                    'This is a quick test notification'
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Immediate test notification sent'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send notification: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notifications),
              label: const Text('Quick Test (Immediate)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final notificationService = NotificationService();
                try {
                  await notificationService.scheduleTestNotification(
                    delaySeconds: 10,
                    title: '🧪 2-Minute Test',
                    body: 'This scheduled test should appear in 2 minutes',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scheduled test notification for 2 minutes'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to schedule notification: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.schedule),
              label: const Text('Quick Test (2min Scheduled)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 20),
            
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Create a floating debug button (for temporary use)
  static Widget createDebugButton(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: () => showDebugMenu(context),
        backgroundColor: Colors.red,
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
    );
  }

  /// Create a debug app bar action (for temporary use)
  static Widget createDebugAction(BuildContext context) {
    return IconButton(
      onPressed: () => showDebugMenu(context),
      icon: const Icon(Icons.bug_report),
      tooltip: 'Debug Menu',
    );
  }
}
