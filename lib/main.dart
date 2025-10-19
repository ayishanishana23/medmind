import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:medmind/screens/admin/admin_home.dart';
import 'package:medmind/screens/auth/await_approval.dart';
import 'package:medmind/screens/auth/login_screen.dart';
import 'package:medmind/screens/splash/initial_splash.dart';
import 'package:medmind/screens/user/user_home.dart';
import 'package:medmind/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Initialize timezone + notification plugin first
  await NotificationService().init();

  // ✅ Request notification permissions (Android 13+ and iOS)
  await _handleNotificationPermission();

  runApp(const MedMindApp());
}

// 🔔 Ask permission safely
Future<void> _handleNotificationPermission() async {
  if (Platform.isAndroid) {
    final androidVersion = int.parse(Platform.operatingSystemVersion
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 2));
    // Only Android 13+ (API 33) needs explicit permission
    if (androidVersion >= 13) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
      }

      if (status.isGranted) {
        debugPrint("✅ Notification permission granted (Android)");
      } else {
        debugPrint("🚫 Notification permission denied (Android)");
      }
    }
  } else if (Platform.isIOS) {
    final status = await Permission.notification.request();
    debugPrint(status.isGranted
        ? "✅ Notification permission granted (iOS)"
        : "🚫 Notification permission denied (iOS)");
  }
}

class MedMindApp extends StatelessWidget {
  const MedMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedMind',
      theme: ThemeData.light(),
      home: const InitialSplash(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 🟢 Auth gate to choose user/admin screen
class Gate extends StatelessWidget {
  const Gate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (!snap.hasData) return const LoginScreen();
        final user = snap.data!;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.doc('users/${user.uid}').snapshots(),
          builder: (_, userSnap) {
            if (!userSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final data = userSnap.data!.data() as Map<String, dynamic>?;
            final approved = data?['approved'] ?? false;
            final role = data?['role'] ?? 'user';
            if (!approved && role != 'admin') return const AwaitApproval();
            return role == 'admin' ? const AdminHome() : const UserHome();
          },
        );
      },
    );
  }
}
