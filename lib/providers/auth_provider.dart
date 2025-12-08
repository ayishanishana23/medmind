import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  AppUser? currentUser;

  AuthProvider() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        fetchUser(user.uid);
      } else {
        currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> fetchUser(String uid) async {
    try {
      final snapshot = await FirebaseAuth.instance.currentUser;
      if (snapshot != null) {
        currentUser = AppUser(
          id: snapshot.uid,
          name: snapshot.displayName ?? '',
          email: snapshot.email ?? '',
          role: 'user',
          approved: true,
          createdAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
  }

  User? get user => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}
