import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/notification_service.dart';

class NotificationDiagnostic {
  static final NotificationService _notificationService = NotificationService();

  /// Comprehensive diagnostic test for notification issues
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};
    
    try {
      debugPrint('🔍 Starting notification diagnostics...');
      
      // 1. Check basic permissions
      results['notifications_enabled'] = await _notificationService.areNotificationsAllowed();
      results['exact_alarms_enabled'] = await _notificationService.canScheduleExactAlarms();
      
      // 2. Check timezone setup
      results['current_timezone'] = tz.local.name;
      results['current_time'] = tz.TZDateTime.now(tz.local).toString();
      
      // 3. Test immediate notification
      try {
        await _notificationService.showNotification(
          999,
          'Test Notification',
          'This is a test notification to verify basic functionality'
        );
        results['immediate_notification'] = 'SUCCESS';
      } catch (e) {
        results['immediate_notification'] = 'FAILED: $e';
      }
      
      // 4. Test scheduled notification (5 seconds from now)
      try {
        await _testScheduledNotification();
        results['scheduled_notification'] = 'SCHEDULED';
      } catch (e) {
        results['scheduled_notification'] = 'FAILED: $e';
      }
      
      // 5. Check pending notifications
      final pending = await _notificationService.getAllScheduledNotifications();
      results['pending_notifications_count'] = pending.length;
      results['pending_notifications'] = pending.map((n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'payload': n.payload,
      }).toList();
      
      // 6. Device info
      results['flutter_version'] = 'Check with flutter --version';
      results['plugin_version'] = '17.2.3'; // From pubspec.yaml
      
      debugPrint('✅ Diagnostics completed');
      return results;
      
    } catch (e) {
      debugPrint('❌ Diagnostics failed: $e');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Test scheduled notification with multiple modes
  static Future<void> _testScheduledNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    
    const androidDetails = AndroidNotificationDetails(
      'diagnostic_channel',
      'Diagnostic Notifications',
      channelDescription: 'Test notifications for diagnostics',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const platformDetails = NotificationDetails(android: androidDetails);
    
    // Test with exact timing
    final exactTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    
    try {
      await plugin.zonedSchedule(
        998,
        '🔔 Diagnostic Test (Exact)',
        'This notification should appear in 5 seconds with exact timing',
        exactTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('✅ Scheduled exact notification for ${exactTime.toString()}');
    } catch (e) {
      debugPrint('❌ Failed to schedule exact notification: $e');
    }
    
    // Test with inexact timing as fallback
    final inexactTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    
    try {
      await plugin.zonedSchedule(
        997,
        '🔔 Diagnostic Test (Inexact)',
        'This notification should appear in 10 seconds with inexact timing',
        inexactTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('✅ Scheduled inexact notification for ${inexactTime.toString()}');
    } catch (e) {
      debugPrint('❌ Failed to schedule inexact notification: $e');
    }
  }

  /// Print detailed diagnostic report
  static void printDiagnosticReport(Map<String, dynamic> results) {
    debugPrint('\n' + '=' * 50);
    debugPrint('📊 NOTIFICATION DIAGNOSTIC REPORT');
    debugPrint('=' * 50);
    
    debugPrint('🔐 PERMISSIONS:');
    debugPrint('  Notifications Enabled: ${results['notifications_enabled']}');
    debugPrint('  Exact Alarms Enabled: ${results['exact_alarms_enabled']}');
    
    debugPrint('\n⏰ TIMEZONE:');
    debugPrint('  Current Timezone: ${results['current_timezone']}');
    debugPrint('  Current Time: ${results['current_time']}');
    
    debugPrint('\n🧪 TESTS:');
    debugPrint('  Immediate Notification: ${results['immediate_notification']}');
    debugPrint('  Scheduled Notification: ${results['scheduled_notification']}');
    
    debugPrint('\n📋 PENDING NOTIFICATIONS:');
    debugPrint('  Count: ${results['pending_notifications_count']}');
    
    if (results['pending_notifications'] != null) {
      final pending = results['pending_notifications'] as List;
      for (int i = 0; i < pending.length && i < 5; i++) {
        final notif = pending[i];
        debugPrint('  ${i + 1}. ID: ${notif['id']}, Title: ${notif['title']}');
      }
      if (pending.length > 5) {
        debugPrint('  ... and ${pending.length - 5} more');
      }
    }
    
    if (results['error'] != null) {
      debugPrint('\n❌ ERROR:');
      debugPrint('  ${results['error']}');
    }
    
    debugPrint('\n💡 TROUBLESHOOTING TIPS:');
    debugPrint('  1. Check device notification settings for MedMind app');
    debugPrint('  2. Disable battery optimization for MedMind');
    debugPrint('  3. Check "Do Not Disturb" mode settings');
    debugPrint('  4. Verify exact alarm permission in device settings');
    debugPrint('  5. Try restarting the device');
    debugPrint('=' * 50 + '\n');
  }

  /// Test different scheduling modes
  static Future<void> testAllScheduleModes() async {
    final plugin = FlutterLocalNotificationsPlugin();
    
    const androidDetails = AndroidNotificationDetails(
      'test_modes_channel',
      'Test Schedule Modes',
      channelDescription: 'Testing different Android schedule modes',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const platformDetails = NotificationDetails(android: androidDetails);
    
    final modes = [
      AndroidScheduleMode.exact,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexact,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];
    
    for (int i = 0; i < modes.length; i++) {
      final mode = modes[i];
      final scheduleTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: 15 + (i * 5)));
      
      try {
        await plugin.zonedSchedule(
          990 + i,
          '🧪 Mode Test: ${mode.name}',
          'Testing ${mode.name} - should appear at ${scheduleTime.toString().substring(11, 19)}',
          scheduleTime,
          platformDetails,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('✅ Scheduled notification with ${mode.name} for ${scheduleTime.toString()}');
      } catch (e) {
        debugPrint('❌ Failed to schedule with ${mode.name}: $e');
      }
    }
  }

  /// Clear all diagnostic test notifications
  static Future<void> clearDiagnosticNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    
    // Cancel diagnostic notifications (IDs 990-999)
    for (int i = 990; i <= 999; i++) {
      await plugin.cancel(i);
    }
    
    debugPrint('✅ Cleared all diagnostic notifications');
  }
}
