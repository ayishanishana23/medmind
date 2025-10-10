import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';

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
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.group, color: AppColors.primary),
            title: const Text("Enable Multi-Profile Management"),
            subtitle: const Text("Manage multiple family profiles under one account"),
            trailing: Switch(
              value: _multiProfileEnabled,
              onChanged: _toggleMultiProfile,
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.lock, color: AppColors.primary),
            title: Text("Privacy & Security"),
            subtitle: Text("Manage security settings"),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.help_outline, color: AppColors.primary),
            title: Text("Help Center"),
            subtitle: Text("Contact or learn more"),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
