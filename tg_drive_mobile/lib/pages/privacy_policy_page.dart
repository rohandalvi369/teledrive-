import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('TeleDrive Privacy Policy', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          _section(context, 'Information We Collect',
            'When you use TeleDrive, we collect certain information to provide and improve our service:\n\n'
            '• Telegram account credentials (phone number, authentication data)\n'
            '• File metadata (file names, sizes, types, timestamps)\n'
            '• Device information for backup functionality\n'
            '• Usage statistics to improve the application'),
          const SizedBox(height: 16),
          _section(context, 'How We Use Your Information',
            'Your information is used solely for:\n\n'
            '• Authenticating you with Telegram\n'
            '• Storing and retrieving your files via Telegram\n'
            '• Providing backup services for your selected folders\n'
            '• Improving application performance and user experience'),
          const SizedBox(height: 16),
          _section(context, 'Data Storage',
            'All files and data are stored on Telegram\'s servers. TeleDrive does not maintain its own servers for file storage. '
            'We do not store your files, passwords, or personal data on any external services outside of Telegram.'),
          const SizedBox(height: 16),
          _section(context, 'Data Sharing',
            'We do not sell, trade, or share your personal information with third parties. '
            'Your data is stored exclusively on Telegram\'s infrastructure and is subject to Telegram\'s privacy policy.'),
          const SizedBox(height: 16),
          _section(context, 'Security',
            'We implement industry-standard security measures to protect your data during transmission. '
            'All communications with Telegram servers are encrypted. However, no method of electronic storage is 100% secure.'),
          const SizedBox(height: 16),
          _section(context, 'Your Rights',
            'You have the right to:\n\n'
            '• Access your data at any time through the app\n'
            '• Delete your files and data\n'
            '• Disable automatic backups\n'
            '• Delete your account and all associated data\n'
            '• Contact us with privacy concerns'),
          const SizedBox(height: 16),
          _section(context, 'Contact',
            'For privacy-related inquiries, please contact:\nrohandalvi369@gmail.com'),
          const SizedBox(height: 16),
          Text('Last updated: May 2026', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
      ],
    );
  }
}
