import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/screens/user/notification_screen.dart';
import 'package:medmind/screens/user/profile/my_account_screen.dart';
import '../../../core/constants.dart';
import '../settings_screen.dart';
import '../user_home.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  String? displayName;
  String? email;
  String? gender;
  String? photoUrl;
  bool isFetching = true;
  bool _multiProfileEnabled = false;
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    final snap =
    await FirebaseFirestore.instance.collection("users").doc(user!.uid).get();

    Map<String, dynamic>? data;

    if (snap.exists) {
      data = snap.data()!;
      displayName = data["displayName"] ?? user!.displayName ?? "No Name";
      email = user!.email;
      gender = data["gender"];
      photoUrl = data["photoUrl"] ?? user!.photoURL;

      _setGenderAvatarIfNull();
    }

    _multiProfileEnabled = data?['multiProfileEnabled'] ?? false;

    if (_multiProfileEnabled) {
      final profilesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('profiles')
          .orderBy('createdAt', descending: false)
          .get();

      _profiles = profilesSnap.docs.map((d) => d.data()).toList();
    }

    setState(() => isFetching = false);
  }

  Future<void> _addProfile() async {
    final nameController = TextEditingController();
    String selectedGender = 'Male';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Profile Name"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedGender,
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => selectedGender = v!,
              decoration: const InputDecoration(labelText: "Gender"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final profileId = DateTime.now().millisecondsSinceEpoch.toString();
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('profiles')
                  .doc(profileId)
                  .set({
                'profileId': profileId,
                'name': name,
                'gender': selectedGender,
                'createdAt': FieldValue.serverTimestamp(),
              });

              setState(() {
                _profiles.add({
                  'profileId': profileId,
                  'name': name,
                  'gender': selectedGender,
                });
              });

              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final nameController = TextEditingController(text: profile['name']);
    String selectedGender = profile['gender'] ?? 'Male';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Profile Name"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedGender,
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => selectedGender = v!,
              decoration: const InputDecoration(labelText: "Gender"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final updatedName = nameController.text.trim();
              if (updatedName.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('profiles')
                  .doc(profile['profileId'])
                  .update({
                'name': updatedName,
                'gender': selectedGender,
              });

              setState(() {
                final index = _profiles.indexWhere(
                        (p) => p['profileId'] == profile['profileId']);
                if (index != -1) {
                  _profiles[index]['name'] = updatedName;
                  _profiles[index]['gender'] = selectedGender;
                }
              });

              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProfile(String profileId) async {
    if (user == null) return;
    if (profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid profile id")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Profile"),
        content: const Text("Are you sure you want to delete this profile? This will also delete medicines assigned to this profile."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isFetching = true);

    try {
      final uid = user!.uid;
      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profiles')
          .doc(profileId);

      // 1) Delete related medicines that have a `profileId` field referencing this profile.
      //    (Adjust this if your app stores medicines inside profiles subcollection instead.)
      final medsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medicines')
          .where('profileId', isEqualTo: profileId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in medsQuery.docs) {
        batch.delete(doc.reference);
        // Optionally: also delete related notification docs for that medicine
        // (if you save notification docs with medicineId, add another query here)
      }

      // 2) Delete the profile doc itself
      batch.delete(profileRef);

      // Commit batch
      await batch.commit();

      // 3) Update local UI list
      setState(() {
        _profiles.removeWhere((p) => p['profileId'] == profileId);
        isFetching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile and related medicines deleted")),
      );
    } catch (e, st) {
      setState(() => isFetching = false);
      debugPrint("Error deleting profile: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting profile: $e")),
      );
    }
  }


  void _setGenderAvatarIfNull() {
    if (photoUrl != null && photoUrl!.isNotEmpty) return;
    if (gender == "Male") photoUrl = "assets/images/male.jpg";
    else if (gender == "Female") photoUrl = "assets/images/female.jpg";
    else photoUrl = "assets/images/avatar.png";
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Logout")),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  ImageProvider<Object> _getAvatar() {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      if (photoUrl!.startsWith("assets/")) return AssetImage(photoUrl!);
      return NetworkImage(photoUrl!);
    }
    if (gender == "Male") return const AssetImage("assets/images/male.jpg");
    if (gender == "Female") return const AssetImage("assets/images/female.jpg");
    return const AssetImage("assets/images/avatar.png");
  }

  @override
  Widget build(BuildContext context) {
    if (isFetching) return const Center(child: CircularProgressIndicator());

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserHome()));
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserHome()));
            },
          ),
          title: const Text("Your Profile", style: TextStyle(color: AppColors.textDark)),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(radius: 50, backgroundImage: _getAvatar()),
              const SizedBox(height: 12),
              Text(displayName ?? "No Name",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(email ?? "No Email", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              if (_multiProfileEnabled) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _addProfile,
                  icon: const Icon(Icons.person_add),
                  label: const Text("Add Profile"),
                ),
                const SizedBox(height: 10),
                if (_profiles.isNotEmpty)
                  Column(
                    children: _profiles.map((p) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: AssetImage(
                              p['gender'] == 'Male'
                                  ? 'assets/images/male.jpg'
                                  : p['gender'] == 'Female'
                                  ? 'assets/images/female.jpg'
                                  : 'assets/images/avatar.png',
                            ),
                          ),
                          title: Text(p['name']),
                          subtitle: Text(p['gender'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editProfile(p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteProfile(p['profileId']),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    _buildProfileOption(
                      icon: Icons.person,
                      text: "My Account",
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAccountScreen()));
                        await _loadUserData();
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.notifications,
                      text: "Notifications",
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.settings,
                      text: "Settings",
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.logout,
                      text: "Log Out",
                      onTap: _logout,
                      isLogout: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.red : AppColors.primary),
        title: Text(
          text,
          style: TextStyle(
            color: isLogout ? Colors.red : AppColors.textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
