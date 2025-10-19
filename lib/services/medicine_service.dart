// lib/services/medicine_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/services/notification_service.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Delete a medicine and cancel all associated notifications
  Future<void> deleteMedicine({
    required String uid,
    required String medId,
  }) async {
    final medRef = _firestore.collection('users').doc(uid).collection('medicines').doc(medId);

    try {
      // 1️⃣ Cancel all notifications linked to this medicine
      await _notificationService.cancelMedicineNotifications(medId);
      
      // Also cancel low stock notification
      await _notificationService.cancelLowStockNotification(medId);

      // 2️⃣ Delete logs if needed
      final logSnapshot = await medRef.collection('logs').get();
      for (var logDoc in logSnapshot.docs) {
        await logDoc.reference.delete();
      }

      // 3️⃣ Delete the medicine document
      await medRef.delete();
      
      print('✅ Medicine $medId deleted successfully with all notifications cancelled');
    } catch (e) {
      print('❌ Error deleting medicine $medId: $e');
      rethrow;
    }
  }

  /// Update medicine stock and check for low stock alerts
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
      
      // Update stock in Firestore
      await medRef.update({'stock': newStock});
      
      // Check if we need to trigger low stock notification
      if (newStock <= lowStockThreshold && newStock > 0) {
        await _notificationService.scheduleLowStockNotification(
          medId: medId,
          medName: medicineName,
          profileId: profileId,
          profileName: profileName,
          stockThreshold: newStock,
          delaySeconds: 1, // Show immediately
        );
      }
      
      print('✅ Medicine stock updated: $medicineName now has $newStock units');
    } catch (e) {
      print('❌ Error updating medicine stock: $e');
      rethrow;
    }
  }
}
