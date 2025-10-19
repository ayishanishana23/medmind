import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/notification_diagnostic.dart';
import '../services/notification_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final NotificationService _notificationService = NotificationService();
  Map<String, dynamic>? _diagnosticResults;
  bool _isRunningDiagnostics = false;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.init();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunningDiagnostics = true;
      _logs = 'Running diagnostics...\n';
    });

    try {
      final results = await NotificationDiagnostic.runDiagnostics();
      setState(() {
        _diagnosticResults = results;
        _isRunningDiagnostics = false;
      });
      
      // Print to console for debugging
      NotificationDiagnostic.printDiagnosticReport(results);
      
      _addLog('Diagnostics completed successfully');
    } catch (e) {
      setState(() {
        _isRunningDiagnostics = false;
      });
      _addLog('Diagnostics failed: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs += '${DateTime.now().toString().substring(11, 19)}: $message\n';
    });
  }

  Future<void> _testImmediateNotification() async {
    try {
      await _notificationService.showNotification(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🧪 Test Notification',
        'This is an immediate test notification'
      );
      _addLog('Immediate notification sent');
    } catch (e) {
      _addLog('Failed to send immediate notification: $e');
    }
  }

  Future<void> _testScheduledNotification() async {
    try {
      await _notificationService.scheduleTestNotification(
        delaySeconds: 10,
        title: '🧪 10-Second Test',
        body: 'This notification was scheduled for 10 seconds ago',
      );
      _addLog('Scheduled test notification for 10 seconds from now');
    } catch (e) {
      _addLog('Failed to schedule test notification: $e');
    }
  }

  Future<void> _testAllScheduleModes() async {
    try {
      await NotificationDiagnostic.testAllScheduleModes();
      _addLog('Testing all schedule modes - check notifications in next 30 seconds');
    } catch (e) {
      _addLog('Failed to test schedule modes: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _notificationService.cancelAllNotifications();
      await NotificationDiagnostic.clearDiagnosticNotifications();
      _addLog('Cleared all notifications');
    } catch (e) {
      _addLog('Failed to clear notifications: $e');
    }
  }

  Future<void> _checkPendingNotifications() async {
    try {
      final pending = await _notificationService.getAllScheduledNotifications();
      _addLog('Found ${pending.length} pending notifications');
      for (final notif in pending.take(3)) {
        _addLog('  - ID: ${notif.id}, Title: ${notif.title}');
      }
    } catch (e) {
      _addLog('Failed to check pending notifications: $e');
    }
  }

  Widget _buildDiagnosticResults() {
    if (_diagnosticResults == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Diagnostic Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildResultRow('Notifications Enabled', _diagnosticResults!['notifications_enabled']),
            _buildResultRow('Exact Alarms Enabled', _diagnosticResults!['exact_alarms_enabled']),
            _buildResultRow('Current Timezone', _diagnosticResults!['current_timezone']),
            _buildResultRow('Immediate Test', _diagnosticResults!['immediate_notification']),
            _buildResultRow('Scheduled Test', _diagnosticResults!['scheduled_notification']),
            _buildResultRow('Pending Count', _diagnosticResults!['pending_notifications_count']),
            if (_diagnosticResults!['error'] != null)
              _buildResultRow('Error', _diagnosticResults!['error'], isError: true),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, dynamic value, {bool isError = false}) {
    Color getColor() {
      if (isError) return Colors.red;
      if (value == true || value == 'SUCCESS' || value == 'SCHEDULED') return Colors.green;
      if (value == false || value?.toString().contains('FAILED') == true) return Colors.red;
      return Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(
                color: getColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Diagnostics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.amber,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Pixel 3a Notification Issues',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Common causes:\n'
                      '• Battery optimization blocking notifications\n'
                      '• "Do Not Disturb" mode enabled\n'
                      '• App notification permissions disabled\n'
                      '• Exact alarm permission not granted\n'
                      '• Android\'s aggressive power management',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _isRunningDiagnostics ? null : _runDiagnostics,
              icon: _isRunningDiagnostics 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report),
              label: Text(_isRunningDiagnostics ? 'Running Diagnostics...' : 'Run Full Diagnostics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildDiagnosticResults(),
            
            const SizedBox(height: 16),
            
            const Text(
              '🧪 Test Functions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _testImmediateNotification,
                  child: const Text('Test Immediate'),
                ),
                ElevatedButton(
                  onPressed: _testScheduledNotification,
                  child: const Text('Test 10s Delay'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _notificationService.scheduleTestNotification(
                        delaySeconds: 30,
                        title: '🧪 30-Second Test',
                        body: 'This notification was scheduled for 30 seconds ago',
                      );
                      _addLog('Scheduled test notification for 30 seconds from now');
                    } catch (e) {
                      _addLog('Failed to schedule 30s test: $e');
                    }
                  },
                  child: const Text('Test 30s Delay'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _notificationService.scheduleTestNotification(
                        delaySeconds: 60,
                        title: '🧪 1-Minute Test',
                        body: 'This notification was scheduled for 1 minute ago',
                      );
                      _addLog('Scheduled test notification for 1 minute from now');
                    } catch (e) {
                      _addLog('Failed to schedule 1min test: $e');
                    }
                  },
                  child: const Text('Test 1min Delay'),
                ),
                ElevatedButton(
                  onPressed: _testAllScheduleModes,
                  child: const Text('Test All Modes'),
                ),
                ElevatedButton(
                  onPressed: _checkPendingNotifications,
                  child: const Text('Check Pending'),
                ),
                ElevatedButton(
                  onPressed: _clearAllNotifications,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Clear All'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '📝 Logs',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _logs));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logs copied to clipboard')),
                            );
                          },
                          child: const Text('Copy'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _logs = '';
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _logs.isEmpty ? 'No logs yet...' : _logs,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Card(
              color: Colors.lightBlue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Manual Checks for Pixel 3a',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Settings > Apps > MedMind > Notifications > Allow all\n'
                      '2. Settings > Apps > MedMind > Battery > Don\'t optimize\n'
                      '3. Settings > Apps > Special access > Alarms & reminders > MedMind > Allow\n'
                      '4. Settings > Sound > Do Not Disturb > Turn off or configure\n'
                      '5. Developer options > Background check > Disabled (if available)',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
