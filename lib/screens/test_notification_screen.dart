import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../core/constants.dart';

class TestNotificationScreen extends StatefulWidget {
  const TestNotificationScreen({super.key});

  @override
  State<TestNotificationScreen> createState() => _TestNotificationScreenState();
}

class _TestNotificationScreenState extends State<TestNotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _checkNotificationStatus() async {
    final isAllowed = await _notificationService.areNotificationsAllowed();
    setState(() {
      _statusMessage = isAllowed 
          ? '✅ Notifications are enabled' 
          : '❌ Notifications are disabled';
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);
    
    final granted = await _notificationService.requestPermissions();
    
    setState(() {
      _isLoading = false;
      _statusMessage = granted 
          ? '✅ Notification permissions granted' 
          : '❌ Notification permissions denied';
    });
  }

  Future<void> _testImmediateNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and body')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await _notificationService.showNotification(
        1,
        _titleController.text,
        _bodyController.text,
      );
      
      setState(() {
        _statusMessage = '✅ Notification sent successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Failed to send notification: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testMedicineReminder() async {
    setState(() => _isLoading = true);
    
    try {
      final now = DateTime.now();
      final testTime = now.add(const Duration(seconds: 10));
      final timeString = '${testTime.hour.toString().padLeft(2, '0')}:${testTime.minute.toString().padLeft(2, '0')}';
      
      await _notificationService.scheduleDailyReminderForProfile(
        medId: 'test-med-001',
        medName: 'Test Medicine',
        time: timeString,
        label: 'Test',
        beforeAfter: 'After',
        profileId: 'self',
        profileName: 'Test User',
        startDate: now,
        endDate: now.add(const Duration(days: 1)),
      );
      
      setState(() {
        _statusMessage = '✅ Medicine reminder scheduled for $timeString (in 10 seconds)';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Failed to schedule reminder: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testLowStockAlert() async {
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.scheduleLowStockNotification(
        medId: 'test-med-002',
        medName: 'Test Low Stock Medicine',
        profileId: 'self',
        profileName: 'Test User',
        stockThreshold: 5,
        delaySeconds: 5, // Show in 5 seconds
      );
      
      setState(() {
        _statusMessage = '✅ Low stock alert scheduled (in 5 seconds)';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Failed to schedule low stock alert: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _viewScheduledNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final notifications = await _notificationService.getAllScheduledNotifications();
      
      setState(() {
        _statusMessage = '📋 Found ${notifications.length} scheduled notifications';
      });
      
      if (notifications.isNotEmpty && mounted) {
        _showScheduledNotificationsDialog(notifications);
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Failed to get scheduled notifications: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showScheduledNotificationsDialog(List notifications) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scheduled Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                title: Text(notification.title ?? 'No Title'),
                subtitle: Text(notification.body ?? 'No Body'),
                trailing: Text('ID: ${notification.id}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAllNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.cancelAllNotifications();
      
      setState(() {
        _statusMessage = '✅ All notifications cancelled';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Failed to cancel notifications: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                color: _statusMessage.contains('✅') 
                    ? Colors.green.shade50 
                    : _statusMessage.contains('❌')
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _statusMessage.isEmpty ? 'Ready to test notifications' : _statusMessage,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Input Fields
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Notification Title',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 10),
              
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Notification Body',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Permission Section
              const Text(
                'Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _checkNotificationStatus,
                icon: const Icon(Icons.check_circle),
                label: const Text('Check Permission Status'),
              ),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _requestPermissions,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Request Permissions'),
              ),
              
              const SizedBox(height: 20),
              
              // Test Section
              const Text(
                'Test Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testImmediateNotification,
                icon: const Icon(Icons.send),
                label: const Text('Send Immediate Notification'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testMedicineReminder,
                icon: const Icon(Icons.medication),
                label: const Text('Schedule Medicine Reminder (10s)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _testLowStockAlert,
                icon: const Icon(Icons.warning),
                label: const Text('Schedule Low Stock Alert (5s)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              
              const SizedBox(height: 20),
              
              // Management Section
              const Text(
                'Notification Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _viewScheduledNotifications,
                icon: const Icon(Icons.list),
                label: const Text('View Scheduled Notifications'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _cancelAllNotifications,
                icon: const Icon(Icons.clear_all),
                label: const Text('Cancel All Notifications'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              
            //  const Spacer(),
              
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
