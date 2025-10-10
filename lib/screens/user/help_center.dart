import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';

class HelpCenter extends StatelessWidget {
  const HelpCenter({super.key});

  // Function to launch email
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@medmindapp.com',
      query: 'subject=Help Needed with MedMind App',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }if (!await launchUrl(emailUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch email app');
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Need Help?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you are facing any issues or need support, please contact us at:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _launchEmail,
              child: const Text(
                '📧 support@medmindapp.com',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can also visit our FAQ section in future updates for quick answers.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
