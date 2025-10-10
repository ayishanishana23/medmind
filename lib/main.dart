import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

// 🟡 Handle background FCM messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  await NotificationService().showPushNotification(message);
  print('✅ Background FCM handled: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Initialize notification service
  await NotificationService().init();

  // ✅ Request permission for local + push notifications
  if (Platform.isAndroid) {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      print("🚫 Notification permission denied");
    }
  }

  // ✅ Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Initialize FCM and store device token in Firestore
  final fcm = FirebaseMessaging.instance;
  final token = await fcm.getToken();
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
  }

  // ✅ Foreground notification listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('📨 Foreground FCM received: ${message.notification?.title}');
    await NotificationService().showPushNotification(message);
  });

  // ✅ When user taps notification (while app is backgrounded)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📬 Notification clicked: ${message.notification?.title}');
  });

  runApp(const MedMindApp());
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

// 🟢 Auth gate to choose user screen
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
