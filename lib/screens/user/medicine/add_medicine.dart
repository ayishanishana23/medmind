// lib/screens/user/medicine/add_medicine_screen.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/medicine.dart';
import '../../../services/notification_service.dart';
import '../../../utils/debug_menu.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine;
  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final dosageController = TextEditingController();
  final stockController = TextEditingController();
  final lowStockController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;
  DateTime? expiryDate;

  List<Map<String, String>> selectedTimes = [];

  bool isLoading = false;

  final Map<String, String> _presetTimes = {
    "Morning": "08:00",
    "Afternoon": "12:00",
    "Evening": "18:00",
    "Night": "21:00",
  };

  // Multi-profile
  bool _multiProfileEnabled = false;
  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _selectedProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfiles().then((_) {
      if (widget.medicine != null) _loadMedicineForEdit();
    });
  }

  Future<void> _loadUserProfiles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userSnap =
    await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
    _multiProfileEnabled = userSnap.data()?['multiProfileEnabled'] ?? false;

    if (_multiProfileEnabled) {
      final profilesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('profiles')
          .get();

      _profiles = profilesSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _profiles.insert(0, {'id': 'self', 'name': 'Self'});
    } else {
      _profiles = [
        {'id': 'self', 'name': 'Self'},
      ];
    }

    if (_profiles.isNotEmpty) _selectedProfile = _profiles.first;
    setState(() {});
  }

  void _loadMedicineForEdit() {
    final med = widget.medicine!;
    nameController.text = med.name;
    dosageController.text = med.dosage;
    stockController.text = med.stock.toString();
    lowStockController.text = med.lowStockAlert.toString();
    startDate = med.startDate;
    endDate = med.endDate;
    expiryDate = med.expiryDate;
    selectedTimes = med.times.map((e) => Map<String, String>.from(e)).toList();

    if (_profiles.isNotEmpty) {
      _selectedProfile = _profiles.firstWhere(
            (p) => p['id'] == med.profileId,
        orElse: () => _profiles.first,
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    stockController.dispose();
    lowStockController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (startDate ?? DateTime.now())
          : (endDate ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          startDate = picked;
        else
          endDate = picked;
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => expiryDate = picked);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final dt = DateTime(0, 0, 0, t.hour, t.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _addCustomTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return;
    final timeStr = _formatTimeOfDay(t);

    selectedTimes.add({
      'label': 'Custom',
      'time': timeStr,
      'beforeAfter': 'After',
    });
    setState(() {});
  }

  void _togglePreset(String label) {
    final existing = selectedTimes.indexWhere((e) => e['label'] == label);
    if (existing >= 0) {
      setState(() => selectedTimes.removeAt(existing));
    } else {
      setState(() {
        selectedTimes.add({
          'label': label,
          'time': _presetTimes[label]!,
          'beforeAfter': 'After',
        });
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select course start and end dates")),
      );
      return;
    }

    if (selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one time")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final isEdit = widget.medicine != null;

      final docRef = isEdit
          ? FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("medicines")
          .doc(widget.medicine!.id)
          : FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("medicines")
          .doc();

      final med = Medicine(
        id: docRef.id,
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        stock: int.tryParse(stockController.text.trim()) ?? 0,
        lowStockAlert: int.tryParse(lowStockController.text.trim()) ?? 0,
        times: selectedTimes
            .map((t) => {
          'label': t['label']!,
          'time': t['time']!,
          'beforeAfter': t['beforeAfter']!,
        })
            .toList(),
        imageUrl: '', // ✅ placeholder — no upload
        startDate: startDate!,
        endDate: endDate!,
        expiryDate: expiryDate ?? endDate!,
        active: true,
        profileId: _selectedProfile?['id'] ?? 'self',
        profileName: _selectedProfile?['name'] ?? 'Self',
      );

      await docRef.set(med.toMap(), SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? "✅ Medicine updated" : "✅ Medicine added"),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }

      // 🔔 Background notifications (unchanged)
      Future.delayed(const Duration(milliseconds: 500), () async {
        final notifier = NotificationService();
        final notificationsAllowed = await notifier.areNotificationsAllowed();
        final exactAllowed = await notifier.canScheduleExactAlarms();

        if (!notificationsAllowed) {
          debugPrint("⚠️ Notifications disabled. Skipping scheduling.");
          return;
        }

        if (isEdit) {
          await notifier.cancelMedicineNotifications(med.id, med.profileId);
        }

        final now = DateTime.now();
        final List<Future> tasks = [];

        for (var t in med.times) {
          tasks.add(Future(() async {
            try {
              final parts = t['time']!.split(':');
              int hour = int.parse(parts[0]);
              int minute = int.parse(parts[1]);

              DateTime firstDate =
              DateTime(now.year, now.month, now.day, hour, minute);
              if (firstDate.isBefore(now)) {
                firstDate = now.add(const Duration(seconds: 10));
              }

              await notifier.scheduleDailyReminderForProfile(
                medId: med.id,
                medName: med.name,
                time: t['time']!,
                label: t['label']!,
                beforeAfter: t['beforeAfter']!,
                profileId: med.profileId,
                profileName: med.profileName,
                startDate: firstDate,
                endDate: med.endDate,
                dosage: med.dosage,
              );
            } catch (e) {
              debugPrint("❌ Error scheduling '${t['label']}': $e");
            }
          }));
        }

        await Future.wait(tasks);
        debugPrint("📅 All reminders scheduled for ${med.name}");
      });
    } catch (e, st) {
      debugPrint("❌ Error saving medicine: $e\n$st");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Medicine" : "Add Medicine"),
        backgroundColor: AppColors.primary,
       // actions: [
       //   if (kDebugMode) DebugMenu.createDebugAction(context),
       // ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ✅ Placeholder avatar (no upload)
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.medication_outlined,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 12),

              // Multi-profile dropdown
              DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                value: _selectedProfile,
                items: _profiles
                    .map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p['name'] ?? 'No Name'),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedProfile = val),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Medicine Name",
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                val == null || val.trim().isEmpty ? "Please enter name" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: dosageController,
                decoration: const InputDecoration(
                  labelText: "Dosage (e.g. 1 tablet)",
                  prefixIcon: Icon(Icons.local_hospital),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                val == null || val.trim().isEmpty ? "Please enter dosage" : null,
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: const Text("Times per Day",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._presetTimes.keys.map((t) => ChoiceChip(
                    label: Text(t),
                    selected: selectedTimes.any((e) => e['label'] == t),
                    onSelected: (_) => _togglePreset(t),
                  )),
                  ActionChip(
                    avatar: const Icon(Icons.add),
                    label: const Text("Custom"),
                    onPressed: _addCustomTime,
                  ),
                ],
              ),

              if (selectedTimes.isNotEmpty)
                ...selectedTimes.map((t) {
                  final index = selectedTimes.indexOf(t);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text("${t['label']} — ${t['time']}")),
                              IconButton(
                                icon:
                                const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    setState(() => selectedTimes.removeAt(index)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ToggleButtons(
                            isSelected: [
                              t['beforeAfter'] == 'Before',
                              t['beforeAfter'] == 'After'
                            ],
                            onPressed: (i) {
                              setState(() {
                                t['beforeAfter'] = i == 0 ? 'Before' : 'After';
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            fillColor:
                            AppColors.primary.withOpacity(0.15),
                            selectedColor: AppColors.primary,
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text("Before Meal"),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text("After Meal"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const Divider(height: 32),

              ListTile(
                title: Text(startDate == null
                    ? "Select Start Date"
                    : "Start: ${DateFormat('dd/MM/yyyy').format(startDate!)}"),
                trailing: const Icon(Icons.event),
                onTap: () => _pickDate(isStart: true),
              ),
              ListTile(
                title: Text(endDate == null
                    ? "Select End Date"
                    : "End: ${DateFormat('dd/MM/yyyy').format(endDate!)}"),
                trailing: const Icon(Icons.event),
                onTap: () => _pickDate(isStart: false),
              ),
              ListTile(
                title: Text(expiryDate == null
                    ? "Select Expiry Date"
                    : "Expiry: ${DateFormat('dd/MM/yyyy').format(expiryDate!)}"),
                trailing: const Icon(Icons.event),
                onTap: _pickExpiryDate,
              ),

              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: stockController,
                    decoration:
                    const InputDecoration(labelText: "Stock Quantity"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: lowStockController,
                    decoration:
                    const InputDecoration(labelText: "Low Stock Alert"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: isLoading ? null : _saveMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 24),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEdit ? "Update Medicine" : "Add Medicine"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
