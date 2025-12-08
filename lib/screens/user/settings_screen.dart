import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medmind/screens/user/privacy_security.dart';
import '../../core/constants.dart';
import 'help_center.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _multiProfileEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      setState(() {
        _multiProfileEnabled = doc.data()?['multiProfileEnabled'] ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMultiProfile(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _multiProfileEnabled = value);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'multiProfileEnabled': value,
    });
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            child: SwitchListTile(
              value:_multiProfileEnabled,
              onChanged: _toggleMultiProfile,
              title: const Text("Enable Multi-Profile"),
              subtitle: const Text("Manage multiple profiles under one account"),
              secondary: const Icon(Icons.people, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),


          Card(
            elevation: 1,
            child: ListTile(
              leading: const Icon(Icons.lock, color: AppColors.primary),
              title: const Text("Privacy & Security"),
              subtitle: const Text("Manage security settings"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
                );              },
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 1,
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.primary),
              title: const Text("Help Center"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpCenter()),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 1,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}
