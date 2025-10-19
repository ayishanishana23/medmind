import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:medmind/screens/admin/admin_home.dart';
import 'package:medmind/screens/auth/await_approval.dart';
import 'package:medmind/screens/auth/login_screen.dart';
import 'package:medmind/screens/splash/splash_screen.dart';
import 'package:medmind/screens/user/user_home.dart';
import 'package:medmind/services/notification_service.dart';
import 'package:medmind/core/constants.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service with proper permission handling
  final notificationService = NotificationService();
  final initialized = await notificationService.init();
  
  if (!initialized) {
    debugPrint("⚠️ App started but notifications are disabled due to permission issues");
  } else {
    // Setup notification listeners for handling user interactions
    NotificationService.setupListeners();
    debugPrint("✅ Notification service initialized and listeners setup");
  }

  runApp(const MedMindApp());
}

// Permission handling is now done in NotificationService.init()

// Authentication wrapper that checks login state on app start
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
    debugPrint("🚀 App starting - showing splash screen");
    _checkAuthAndShowSplash();
    
    // Listen for auth changes after initial check
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted && _authChecked) {
        if (user != _currentUser) {
          debugPrint("🔄 Auth state changed - updating UI");
          setState(() {
            _currentUser = user;
          });
        }
      }
    });
  }

  Future<void> _checkAuthAndShowSplash() async {
    // Check current auth state immediately
    _currentUser = FirebaseAuth.instance.currentUser;
    
    if (_currentUser != null) {
      debugPrint("✅ User already logged in: ${_currentUser!.email}");
    } else {
      debugPrint("🚫 No user logged in");
    }
    
    // Show splash for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      debugPrint("⏰ Splash complete - routing to appropriate screen");
      setState(() {
        _authChecked = true;
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show initial splash animation first
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

    // After splash, route based on pre-checked auth state
    if (!_authChecked) {
      // This shouldn't happen, but just in case
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Route based on authentication state checked during splash
    if (_currentUser == null) {
      debugPrint("🚫 Routing to onboarding");
      return const SplashScreen();
    } else {
      debugPrint("✅ Routing to main app for user: ${_currentUser!.email}");
      return const Gate();
    }
  }
}

class MedMindApp extends StatelessWidget {
  const MedMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedMind',
      theme: ThemeData.light(),
      home: const AuthWrapper(),
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
