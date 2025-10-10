import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/profile.dart';

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserProfile> profiles = [];

  Future<void> fetchProfiles(String userId) async {
    try {
      final query = await _firestore
          .collection('profiles')
          .where('userId', isEqualTo: userId)
          .get();

      profiles = query.docs
          .map((doc) => UserProfile.fromMap(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching profiles: $e");
    }
  }

  Future<void> addProfile(UserProfile profile) async {
    try {
      await _firestore.collection('profiles').add(profile.toMap());
      fetchProfiles(profile.userId);
    } catch (e) {
      debugPrint("Error adding profile: $e");
    }
  }

  Future<void> deleteProfile(String profileId, String userId) async {
    try {
      await _firestore.collection('profiles').doc(profileId).delete();
      fetchProfiles(userId);
    } catch (e) {
      debugPrint("Error deleting profile: $e");
    }
  }
}
