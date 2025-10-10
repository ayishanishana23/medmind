import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/screens/user/help_center.dart';
import 'package:medmind/screens/user/notification_screen.dart';
import 'package:medmind/screens/user/profile/my_account_screen.dart';
import 'package:medmind/screens/user/settings_screen.dart';
import '../../../core/constants.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();

    if (snap.exists) {
      final data = snap.data()!;
      displayName = data["displayName"] ?? user!.displayName ?? "No Name";
      email = user!.email;
      gender = data["gender"];
      photoUrl = data["photoUrl"] ?? user!.photoURL;

      // Always check again for gender avatar
      _setGenderAvatarIfNull();
    }

    setState(() => isFetching = false);
  }

  void _setGenderAvatarIfNull() {
    // treat null or empty string as "no uploaded photo"
    if (photoUrl != null && photoUrl!.isNotEmpty) return;

    if (gender == "Male") {
      photoUrl = "assets/images/male.jpg";
    } else if (gender == "Female") {
      photoUrl = "assets/images/female.jpg";
    } else {
      photoUrl = "assets/images/avatar.png";
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to logout: $e")),
      );
    }
  }

  /// Returns avatar based on uploaded photo or gender
  ImageProvider<Object> _getAvatar() {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      if (photoUrl!.startsWith("assets/")) {
        return AssetImage(photoUrl!);
      }
      return NetworkImage(photoUrl!);
    }

    // fallback
    if (gender == "Male") return const AssetImage("assets/images/male.jpg");
    if (gender == "Female") return const AssetImage("assets/images/female.jpg");
    return const AssetImage("assets/images/avatar.png");
  }

  @override
  Widget build(BuildContext context) {
    if (isFetching) return const Center(child: CircularProgressIndicator());

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserHome()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const UserHome()),
              );
            },
          ),
          title: const Text(
            "Your Profile",
            style: TextStyle(color: AppColors.textDark),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(radius: 50, backgroundImage: _getAvatar()),
              const SizedBox(height: 12),
              Text(
                displayName ?? "No Name",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                email ?? "No Email",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  children: [
                    _buildProfileOption(
                      icon: Icons.person,
                      text: "My Account",
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyAccountScreen(),
                          ),
                        );
                        await _loadUserData(); // reload after editing
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.notifications,
                      text: "Notifications",
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.help_outline,
                      text: "Help Center",
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HelpCenter(),
                          ),
                        );
                      },
                    ),
                    _buildProfileOption(
                      icon: Icons.settings,
                      text: "Settings",
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
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
