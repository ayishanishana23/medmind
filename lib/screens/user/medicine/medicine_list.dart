// lib/screens/user/medicine/medicine_list.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants.dart';
import '../../../models/medicine.dart';
import '../../../services/medicine_service.dart';
import 'add_medicine.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  String? selectedProfileId;
  List<Map<String, dynamic>> profiles = [];
  bool isLoadingProfiles = true;

  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .get();
    profiles = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    if (profiles.isNotEmpty) {
      selectedProfileId = profiles.first['id']; // default first profile
    }

    setState(() => isLoadingProfiles = false);
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Medicines"),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(

      body: Column(
        children: [
          // Multi-profile dropdown
          if (!isLoadingProfiles && profiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButton<String>(
                value: selectedProfileId,
                isExpanded: true,
                hint: const Text("Select Profile"),
                items: profiles.map((profile) {
                  return DropdownMenuItem<String>(
                    value: profile['id'],
                    child: Text(profile['name'] ?? 'Unnamed'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedProfileId = val;
                  });
                },
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('medicines')
                  .where('profileId', isEqualTo: selectedProfileId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No medicines added yet"));
                }

                final meds = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Medicine.fromMap(data, doc.id);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: meds.length,
                  itemBuilder: (context, index) {
                    final med = meds[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: med.imageUrl != null && med.imageUrl!.isNotEmpty
                            ? CircleAvatar(
                          backgroundImage: NetworkImage(med.imageUrl!),
                        )
                            : const CircleAvatar(child: Icon(Icons.medical_services)),
                        title: Text(med.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Dosage: ${med.dosage}"),
                            Text("Stock: ${med.stock}"),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: med.times.map((timeEntry) {
                                final label = timeEntry['label'] ?? 'Custom';
                                final time = timeEntry['time'] ?? '08:00';
                                final beforeAfter = timeEntry['beforeAfter'] ?? 'After';
                                return Chip(
                                  label: Text("$label • $time • $beforeAfter meal"),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddMedicineScreen(medicine: med),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Medicine"),
                                    content: const Text(
                                        "Are you sure you want to delete this medicine?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    final medicineService = MedicineService();
                                    await medicineService.deleteMedicine(
                                        uid: uid!, medId: med.id);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                          Text("Medicine deleted successfully")),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("Error deleting medicine: $e")),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
