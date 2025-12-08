import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final user = FirebaseAuth.instance.currentUser;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  DateTime? dob;
  String? gender;
  String? photoUrl;

  bool isEditing = false; // start in view mode
  bool isLoading = false;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    final snap =
    await FirebaseFirestore.instance.collection("users").doc(user!.uid).get();

    if (snap.exists) {
      final data = snap.data()!;
      nameController.text = data["displayName"] ?? user!.displayName ?? "";
      phoneController.text = data["phone"] ?? "";
      emailController.text = data["email"] ?? user!.email ?? "";
      dob = data["dob"] != null ? DateTime.tryParse(data["dob"]) : null;
      gender = data["gender"];
      photoUrl = data["photoUrl"] ?? user!.photoURL;
      _setGenderAvatarIfNull();
    }
    setState(() {});
  }

  /// Set gender-based avatar if no custom image exists
  void _setGenderAvatarIfNull({bool forceUpdate = false}) {
    if (photoUrl != null && !photoUrl!.startsWith("assets/") && !forceUpdate) {
      // Custom uploaded photo → don’t overwrite
      return;
    }

    if (gender == "Male") {
      photoUrl = "assets/images/male.jpg";
    } else if (gender == "Female") {
      photoUrl = "assets/images/female.jpg";
    } else {
      photoUrl = "assets/images/avatar.png";
    }
  }

  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text("Take a Photo"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile =
    await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => isUploading = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_pics/${user!.uid}.jpg");
      await ref.putFile(File(pickedFile.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .update({"photoUrl": url});

      setState(() => photoUrl = url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload profile image")),
      );
    }

    setState(() => isUploading = false);
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance.collection("users").doc(user!.uid).update({
        "displayName": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "dob": dob?.toIso8601String(),
        "gender": gender,
        "photoUrl": photoUrl,
      });

      await user!.updateDisplayName(nameController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("✅ Profile updated"),
            backgroundColor: Colors.green),
      );

      setState(() => isEditing = false); // switch back to view mode
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("❌ Error: $e"), backgroundColor: Colors.red),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: AppColors.textDark),
        title:
        const Text("My Account", style: TextStyle(color: AppColors.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.textDark),
              onPressed: () => setState(() => isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: isEditing ? _buildEditMode() : _buildViewMode(),
      ),
    );
  }

  Widget _buildViewMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundImage: photoUrl != null
                ? (photoUrl!.startsWith("assets/")
                ? AssetImage(photoUrl!) as ImageProvider
                : NetworkImage(photoUrl!))
                : const AssetImage("assets/images/avatar.png"),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle("Basic Detail"),
        _buildDetailRow("Full Name", nameController.text),
        _buildDetailRow(
            "Date of Birth",
            dob != null ? "${dob!.day}/${dob!.month}/${dob!.year}" : "-"),
        _buildDetailRow("Gender", gender ?? "-"),
        const SizedBox(height: 20),
        _buildSectionTitle("Contact Detail"),
        _buildDetailRow("Mobile Number", phoneController.text),
        _buildDetailRow("Email", emailController.text),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEditMode() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: photoUrl != null
                  ? (photoUrl!.startsWith("assets/")
                  ? AssetImage(photoUrl!) as ImageProvider
                  : NetworkImage(photoUrl!))
                  : const AssetImage("assets/images/avatar.png"),
            ),
            InkWell(
              onTap: _showImageSourceSheet,
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        if (isUploading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: CircularProgressIndicator(),
          ),
        const SizedBox(height: 20),
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Full Name"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: "Phone Number"),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: gender,
          items: ["Male", "Female", "Other"]
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (value) {
            setState(() {
              gender = value;
              _setGenderAvatarIfNull(forceUpdate: true); // 🔑 update avatar immediately
            });
          },
          decoration: const InputDecoration(labelText: "Gender"),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(dob == null
              ? "Select Date of Birth"
              : "DOB: ${dob!.day}/${dob!.month}/${dob!.year}"),
          trailing: const Icon(Icons.calendar_today, color: AppColors.primary),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dob ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => dob = picked);
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Save Profile",
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    ),
  );

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value.isEmpty ? "-" : value,
            style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
