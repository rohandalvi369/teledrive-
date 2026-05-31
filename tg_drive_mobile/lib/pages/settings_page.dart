import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/telegram_service.dart';
import 'backup_setup_page.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _clearCache() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear Cache'),
          content: const Text('This will clear all locally cached data. You will stay logged in.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
          ],
        ),
      );
      if (confirmed != true) return;
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('backup_')).toList();
      for (final k in keys) await prefs.remove(k);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')),
        );
      }
    } catch (e) {
      debugPrint('Failed to clear cache: $e');
    }
  }

  Future<void> _clearAllData() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text('This will clear all local data and sign you out. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Clear All', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('backup_')).toList();
      for (final k in keys) await prefs.remove(k);
      if (mounted) {
        context.read<TelegramService>().logout();
      }
    } catch (e) {
      debugPrint('Failed to clear all data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Theme', style: theme.textTheme.titleMedium),
                ]),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness), label: Text('System')),
                  ],
                  selected: {themeService.themeMode},
                  onSelectionChanged: (v) => themeService.setThemeMode(v.first),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.backup, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Auto Backup', style: theme.textTheme.titleMedium)),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSetupPage())),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Configure automatic backup of your device folders', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.cached, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Cache', style: theme.textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                Text('Manage locally cached backup data', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _clearCache, child: const Text('Clear Cache')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                      onPressed: _clearAllData,
                      child: Text('Clear All Data', style: TextStyle(color: theme.colorScheme.onError)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.primary),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text('TeleDrive v1.0.0', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
