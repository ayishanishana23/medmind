import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final medicinesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicines');

    return Scaffold();
  }

  // 🔹 Calculate overall taken and missed doses across all medicines
  Future<List<int>> _calculateTakenMissed(List<QueryDocumentSnapshot> meds) async {
    int totalTaken = 0;
    int totalMissed = 0;

    for (var med in meds) {
      final logsSnapshot = await med.reference.collection('logs').get();
      final logs = logsSnapshot.docs;

      totalTaken += logs.where((log) => log['status'] == 'taken').length;
      totalMissed += logs.where((log) => log['status'] == 'missed').length;
    }

    return [totalTaken, totalMissed];
  }
}
