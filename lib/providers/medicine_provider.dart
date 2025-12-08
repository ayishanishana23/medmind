import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/medicine.dart';

class MedicineProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Medicine> medicines = [];

  Future<void> fetchMedicines(String userId) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .get();

      medicines = query.docs
          .map((doc) => Medicine.fromMap(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching medicines: $e");
    }
  }

  Future<void> addMedicine(String userId, Medicine medicine) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .add(medicine.toMap());

      fetchMedicines(userId);
    } catch (e) {
      debugPrint("Error adding medicine: $e");
    }
  }

  Future<void> updateMedicine(String userId, Medicine medicine) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(medicine.id)
          .update(medicine.toMap());

      fetchMedicines(userId);
    } catch (e) {
      debugPrint("Error updating medicine: $e");
    }
  }

  Future<void> deleteMedicine(String userId, String medicineId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .doc(medicineId)
          .delete();

      medicines.removeWhere((m) => m.id == medicineId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting medicine: $e");
    }
  }
}
