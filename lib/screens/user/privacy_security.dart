import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  // Function to launch website
  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://www.medmindapp.com/privacy');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open website');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [

            const SizedBox(height: 15),
            const Text(
              'We respect your privacy and protect your data using Firebase Authentication and Firestore security rules.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              '🔒 Your personal information is stored securely and never shared with third parties.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _launchWebsite,
              child: const Text(
                'For more details, visit our website or contact support.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
