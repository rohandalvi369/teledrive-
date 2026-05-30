import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/backup_service.dart';
import '../services/api_service.dart';
import '../services/file_service.dart';
import 'backup_progress_page.dart';
import 'backup_status_page.dart';

class BackupSetupPage extends StatefulWidget {
  const BackupSetupPage({super.key});

  @override
  State<BackupSetupPage> createState() => _BackupSetupPageState();
}

class _BackupSetupPageState extends State<BackupSetupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bs = context.read<BackupService>();
      bs.scanDeviceFolders();
      final api = context.read<ApiService>();
      bs.saveServerConfig(
        apiUrl: api.baseUrl,
        session: null,
      );
      final fs = context.read<FileService>();
      if (fs.folders.isEmpty) fs.fetchFolders();
    });
  }

  void _showFolderPicker(BuildContext ctx, FileService fs, BackupService bs) {
    showModalBottomSheet(
      context: ctx,
      builder: (ctx2) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Backup Destination', style: Theme.of(ctx2).textTheme.titleMedium)),
        ...fs.folders.map((f) => ListTile(
          leading: Icon(f.type == 'saved' ? Icons.save : Icons.folder),
          title: Text(f.title),
          trailing: bs.config.destFolderId == f.id ? Icon(Icons.check, color: Theme.of(ctx2).colorScheme.primary) : null,
          onTap: () { bs.setDestFolder(f.id, f.title); Navigator.pop(ctx2); },
        )),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission needed for auto-backup'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bs = context.watch<BackupService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Auto Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Auto Backup',
                            style: theme.textTheme.titleMedium),
                      ),
                      Switch(
                        value: bs.config.autoBackup,
                        onChanged: (v) {
                          if (v) _requestNotificationPermission();
                          bs.setAutoBackup(v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Automatically back up selected folders every 24 hours',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Backup Quality',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: true, label: Text('Original')),
                      ButtonSegment(
                          value: false, label: Text('Compressed')),
                    ],
                    selected: {bs.config.useOriginal},
                    onSelectionChanged: (v) => bs.setQuality(v.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ─── Destination Folder ──────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Destination Folder', style: theme.textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                Consumer<FileService>(
                  builder: (ctx, fs, _) {
                    final destId = bs.config.destFolderId;
                    final destName = bs.config.destFolderName;
                    final selected = destId != null
                        ? fs.folders.where((f) => f.id == destId).firstOrNull
                        : null;
                    return InkWell(
                      onTap: () => _showFolderPicker(ctx, fs, bs),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(selected?.type == 'saved' ? Icons.save : Icons.folder,
                              color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              destName ?? (destId != null ? 'Folder $destId' : 'Select a folder...'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: destName != null ? null : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                        ]),
                      ),
                    );
                  },
                ),
                if (bs.config.destFolderId != null) ...[
                  const SizedBox(height: 8),
                  Text('Backup files will be uploaded to this folder',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed:
                      bs.config.selectedFolderIds.isEmpty || bs.backingUp
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BackupProgressPage(),
                                ),
                              );
                            },
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.backup, size: 18),
                    SizedBox(width: 8),
                    Text('Backup Now'),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: bs.config.selectedFolderIds.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BackupStatusPage(),
                            ),
                          );
                        },
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Status'),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Device Folders',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (bs.scanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (bs.folders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No folders found',
                    style: theme.textTheme.bodyMedium),
              ),
            )
          else
            ...bs.folders.map((folder) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: CheckboxListTile(
                    value: folder.selected,
                    onChanged: (v) =>
                        bs.toggleFolder(folder.id, v ?? false),
                    title: Text(folder.name),
                    subtitle: Text(
                      '${folder.fileCount} files'
                      '${folder.backedUp ? ' · Last backup: ${_formatTime(folder.lastBackupTime)}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: Icon(
                      folder.backedUp
                          ? Icons.cloud_done
                          : Icons.cloud_outlined,
                      color: folder.backedUp ? Colors.green : null,
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  String _formatTime(int ts) {
    if (ts == 0) return 'Never';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
