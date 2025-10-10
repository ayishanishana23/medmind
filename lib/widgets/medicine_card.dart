import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../core/constants.dart';

class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback? onTake;     // ✅ Action for "Take"
  final VoidCallback? onSnooze;   // ✅ Action for "Snooze"
  final VoidCallback? onMiss;     // ✅ Action for "Miss"

  const MedicineCard({
    super.key,
    required this.medicine,
    this.onTake,
    this.onSnooze,
    this.onMiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cornerRadius),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🏥 Medicine Info
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: medicine.imageUrl!.isNotEmpty
                      ? NetworkImage(medicine.imageUrl!)
                      : const AssetImage("assets/images/medicine_placeholder.png")
                  as ImageProvider,
                  radius: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        medicine.dosage,
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                      Text(
                        "Stock: ${medicine.stock} (Low alert: ${medicine.lowStockAlert})",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ⏰ Times row
            Wrap(
              spacing: 8,
              children: medicine.times
                  .map((time) => Chip(
                label: Text("time"),
                backgroundColor: AppColors.background,
              ))
                  .toList(),
            ),

            const SizedBox(height: 12),

            // ✅ Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: onTake,
                  icon: const Icon(Icons.check),
                  label: const Text("Take"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(90, 36),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onSnooze,
                  icon: const Icon(Icons.access_time),
                  label: const Text("Snooze"),
                ),
                OutlinedButton.icon(
                  onPressed: onMiss,
                  icon: const Icon(Icons.close),
                  label: const Text("Missed"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
