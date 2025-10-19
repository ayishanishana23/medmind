// lib/screens/user/medicine/add_medicine_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/medicine.dart';
import '../../../services/notification_service.dart';

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
  File? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  String? existingImageUrl;
  bool isLoading = false;
  final ImagePicker _picker = ImagePicker();

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

      // Always include "Self" option at top
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
    existingImageUrl = med.imageUrl;

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

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageFile = null;
          existingImageUrl = null;
        });
      } else {
        setState(() {
          _pickedImageFile = File(picked.path);
          existingImageUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Image pick failed: $e")));
    }
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

  Future<String> _uploadImageAndGetUrl(String uid, String docId) async {
    if (_pickedImageFile == null &&
        _pickedImageBytes == null &&
        existingImageUrl != null) {
      return existingImageUrl!;
    }
    if (_pickedImageFile == null && _pickedImageBytes == null) return '';

    final ref = FirebaseStorage.instance.ref().child('users/$uid/medicines/$docId.jpg');
    if (kIsWeb) {
      await ref.putData(_pickedImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(_pickedImageFile!);
    }
    return await ref.getDownloadURL();
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select course start and end dates"))
      );
      return;
    }

    if (selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one time"))
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

      final imageUrl = await _uploadImageAndGetUrl(uid, docRef.id);

      final med = Medicine(
        id: docRef.id,
        name: nameController.text.trim(),
        dosage: dosageController.text.trim(),
        stock: int.tryParse(stockController.text.trim()) ?? 0,
        lowStockAlert: int.tryParse(lowStockController.text.trim()) ?? 0,
        times: selectedTimes.map((t) => {
          'label': t['label']!,
          'time': t['time']!,
          'beforeAfter': t['beforeAfter']!,
        }).toList(),
        imageUrl: imageUrl,
        startDate: startDate!,
        endDate: endDate!,
        expiryDate: expiryDate ?? endDate!,
        active: true,
        profileId: _selectedProfile?['id'] ?? 'self',
        profileName: _selectedProfile?['name'] ?? 'Self',
      );

      // Save medicine in Firestore
      await docRef.set(med.toMap(), SetOptions(merge: true));

      final notifier = NotificationService();

      // Schedule daily reminders
      for (var t in med.times) {
        try {
          await notifier.scheduleDailyReminderForProfile(
            medId: med.id,
            medName: med.name,
            time: t['time']!,
            label: t['label']!,
            beforeAfter: t['beforeAfter']!,
            profileId: med.profileId,
            profileName: med.profileName,
          );
        } catch (e) {
          debugPrint("Daily notification error: $e");
        }
      }

      // Schedule low-stock notification if needed
      if (med.lowStockAlert > 0 && med.stock > 0) {
        try {
          final notifId = med.id.hashCode ^ 9999;

          final notifData = {
            'medicineId': med.id,
            'medName': med.name,
            'title': 'Low Stock Alert',
            'body': 'Your medicine "${med.name}" is running low (${med.stock} left)',
            'notificationId': notifId,
            'status': 'pending',
            'type': 'low_stock',
            'userId': uid,
            'profileId': med.profileId,
            'profileName': med.profileName,
            'scheduledAt': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 5))),
            'createdAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .doc(notifId.toString())
              .set(notifData);

          await notifier.scheduleNotificationFromData(notifData);
        } catch (e) {
          debugPrint("Low-stock notification error: $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? "✅ Medicine updated" : "✅ Medicine added")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"))
      );
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _pickedImageFile != null
                      ? FileImage(_pickedImageFile!)
                      : (_pickedImageBytes != null
                      ? MemoryImage(_pickedImageBytes!)
                      : (existingImageUrl != null
                      ? NetworkImage(existingImageUrl!)
                      : null)) as ImageProvider<Object>?,
                  child: (_pickedImageFile == null &&
                      _pickedImageBytes == null &&
                      existingImageUrl == null)
                      ? const Icon(Icons.camera_alt, color: AppColors.primary, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              // Multi-profile selector
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
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please enter medicine name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: dosageController,
                decoration: const InputDecoration(
                  labelText: "Dosage (e.g. 1 tablet)",
                  prefixIcon: Icon(Icons.local_hospital),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Please enter dosage";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Times per Day", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text("${t['label']} — ${t['time']}",
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => setState(() => selectedTimes.removeAt(index)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ToggleButtons(
                            isSelected: [t['beforeAfter'] == 'Before', t['beforeAfter'] == 'After'],
                            onPressed: (i) {
                              setState(() {
                                t['beforeAfter'] = i == 0 ? 'Before' : 'After';
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            fillColor: AppColors.primary.withOpacity(0.15),
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
                    decoration: const InputDecoration(labelText: "Stock Quantity"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: lowStockController,
                    decoration: const InputDecoration(labelText: "Low Stock Alert"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _saveMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
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
