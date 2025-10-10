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

    // 1️⃣ Cancel all notifications linked to this medicine
    final notifSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('medicineId', isEqualTo: medId)
        .get();

    for (var doc in notifSnapshot.docs) {
      final notificationId = doc['notificationId'] as int?;
      if (notificationId != null) {
        await _notificationService.cancelNotificationById(notificationId);
      }
      await doc.reference.delete(); // remove notification doc
    }

    // 2️⃣ Delete logs if needed
    final logSnapshot = await medRef.collection('logs').get();
    for (var logDoc in logSnapshot.docs) {
      await logDoc.reference.delete();
    }

    // 3️⃣ Delete the medicine document
    await medRef.delete();
  }
}
