// lib/services/medicine_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medmind/models/medicine.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// ✅ Add medicine and schedule daily reminders
  Future<void> addMedicine({
    required String uid,
    required Medicine medicine,
  }) async {
    try {
      final medRef = _firestore.collection('users').doc(uid).collection('medicines').doc();

      // Convert to map
      final medData = medicine.toMap();
      medData['id'] = medRef.id;
      medData['createdAt'] = FieldValue.serverTimestamp();

      // Save to Firestore
      await medRef.set(medData);

      print('💊 Medicine ${medicine.name} added for user $uid');

      // Schedule daily reminders for each time entry
      for (var timeEntry in medicine.times) {
        if (timeEntry is Map<String, dynamic>) {
          final time = timeEntry['time'] ?? '08:00';
          final beforeAfter = timeEntry['beforeAfter'] ?? 'After';
          final label = timeEntry['label'] ?? 'Dose';

          await _notificationService.scheduleDailyReminderForProfile(
            medId: medRef.id,
            medName: medicine.name,
            time: time,
            label: label,
            beforeAfter: beforeAfter,
            profileId: medicine.profileId ?? 'self',
            profileName: medicine.profileName ?? 'Self',
            startDate: medicine.startDate,
            endDate: medicine.endDate, dosage:medicine.dosage,
          );
        }
      }


      // Schedule low stock alert if below threshold
      if (medicine.stock <= medicine.lowStockAlert) {
        await _notificationService.scheduleLowStockNotification(
          medId: medRef.id,
          medName: medicine.name,
          profileId: medicine.profileId ?? 'self',
          profileName: medicine.profileName ?? 'Self',
          stockThreshold: medicine.stock,
          delaySeconds: 3,
        );
      }

      print('✅ All reminders scheduled for ${medicine.name}');
    } catch (e) {
      print('❌ Error adding medicine: $e');
      rethrow;
    }
  }

  /// 🗑️ Delete a medicine and cancel all associated notifications
  Future<void> deleteMedicine({
    required String uid,
    required String medId,
  }) async {
    final medRef = _firestore.collection('users').doc(uid).collection('medicines').doc(medId);

    try {
      await _notificationService.cancelMedicineNotifications(medId, uid);
      await _notificationService.cancelLowStockNotification(medId);

      final logSnapshot = await medRef.collection('logs').get();
      for (var logDoc in logSnapshot.docs) {
        await logDoc.reference.delete();
      }

      await medRef.delete();
      print('✅ Medicine $medId deleted successfully with all notifications cancelled');
    } catch (e) {
      print('❌ Error deleting medicine $medId: $e');
      rethrow;
    }
  }

  /// 🔄 Update medicine stock and trigger low-stock alerts
  Future<void> updateMedicineStock({
    required String uid,
    required String medId,
    required int newStock,
    required int lowStockThreshold,
    required String medicineName,
    required String profileId,
    required String profileName,
  }) async {
    try {
      final medRef = _firestore.collection('users').doc(uid).collection('medicines').doc(medId);
      await medRef.update({'stock': newStock});

      if (newStock <= lowStockThreshold && newStock > 0) {
        await _notificationService.scheduleLowStockNotification(
          medId: medId,
          medName: medicineName,
          profileId: profileId,
          profileName: profileName,
          stockThreshold: newStock,
          delaySeconds: 1,
        );
      }

      print('✅ Medicine stock updated: $medicineName now has $newStock units');
    } catch (e) {
      print('❌ Error updating medicine stock: $e');
      rethrow;
    }
  }
}
