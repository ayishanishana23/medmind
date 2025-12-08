import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/screens/admin/admin_home.dart';
import 'package:medmind/screens/auth/await_approval.dart';
import 'package:medmind/screens/auth/login_screen.dart';
import 'package:medmind/screens/splash/splash_screen.dart';
import 'package:medmind/screens/user/medicine/medicine_details.dart';
import 'package:medmind/screens/user/user_home.dart';
import 'package:medmind/services/notification_service.dart';
import 'package:medmind/core/constants.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 🧭 Initialize the FlutterLocalNotificationsPlugin globally
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🪄 Initialize Local Notifications
  const AndroidInitializationSettings androidInit =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
  InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // 🔔 Initialize Notification Service (your custom class)
  final notificationService = NotificationService();
  final initialized = await notificationService.init();

  if (initialized) {
    debugPrint("✅ Notification service initialized");
    NotificationService.setupListeners();
  } else {
    debugPrint("⚠️ Notifications disabled or permission denied");
  }

  runApp(const MedMindApp());
}

class MedMindApp extends StatefulWidget {
  const MedMindApp({super.key});

  @override
  State<MedMindApp> createState() => _MedMindAppState();
}

class _MedMindAppState extends State<MedMindApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // ✅ Listen for notification taps (foreground / background)
    NotificationService().onNotificationClick.listen((payload) {
      _handleNotificationTap(payload);
    });

    // ✅ Handle notification tap if app was launched from a terminated state
    NotificationService.getInitialNotificationPayload().then((payload) {
      if (payload != null) {
        _handleNotificationTap(payload);
      }
    });
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint("🔔 Notification tapped with payload: $payload");

    try {
      final data = NotificationService.parsePayload(payload);

      if (data['type'] == 'medicine_reminder') {
        final medId = data['medId'];
        final medName = data['medName'];
        final dosage = data['dosage'] ?? '';
        final profileId = data['profileId'];
        final profileName = data['profileName'];
        final time = data['time'];
        final label = data['label'];
        final beforeAfter = data['beforeAfter'];

        if (medId != null &&
            medName != null &&
            profileId != null &&
            profileName != null &&
            time != null &&
            label != null &&
            beforeAfter != null) {
          debugPrint("📦 Opening Medicine Detail for ID: $medId");

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_navigatorKey.currentState != null) {
              _navigatorKey.currentState!.push(
                MaterialPageRoute(
                  builder: (_) => MedicineDetailsScreen(
                    medId: medId,
                    medName: medName,
                    dosage: dosage,
                    profileId: profileId,
                    profileName: profileName,
                    time: time,
                    label: label,
                    beforeAfter: beforeAfter,
                    payload: payload,
                  ),
                ),
              );
            } else {
              debugPrint("❌ Navigator is not ready yet");
            }
          });
        }
      } else if (data['type'] == 'low_stock_alert') {
        debugPrint("⚠️ Low stock alert received for ${data['medName']}");
      } else if (data['type'] == 'test_notification' ||
          data['type'] == 'test_time_notification') {
        debugPrint("🧪 Test notification received");
      } else {
        debugPrint("❓ Unknown notification type");
      }
    } catch (e) {
      debugPrint("⚠️ Failed to handle notification payload: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedMind',
      navigatorKey: _navigatorKey,
      theme: ThemeData.light(),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 🔐 Authentication wrapper
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showSplash = true;
  User? _currentUser;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 Showing splash...");
    _checkAuthAndShowSplash();

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted && _authChecked) {
        if (user != _currentUser) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    });
  }

  Future<void> _checkAuthAndShowSplash() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _authChecked = true;
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.5 + (value * 0.5),
                  child: Image.asset(
                    "assets/images/loogoo.png",
                    height: 120,
                    width: 120,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (!_authChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return const SplashScreen();
    } else {
      return const Gate();
    }
  }
}

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
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
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
