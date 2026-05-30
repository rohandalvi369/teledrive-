import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import 'backup_progress_page.dart';

class BackupStatusPage extends StatelessWidget {
  const BackupStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bs = context.watch<BackupService>();
    final theme = Theme.of(context);

    final backedUpFolders = bs.folders.where((f) => f.backedUp).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Backup Status')),
      body: backedUpFolders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No backups yet',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Select folders in Backup setup and run your first backup',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Backed Up Folders',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...backedUpFolders.map((folder) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder,
                                  color: Colors.green, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(folder.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight:
                                                  FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${folder.fileCount} files · ${_formatSize(folder.storageUsed)}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant),
                                  ),
                                  Text(
                                    'Last: ${_formatTime(folder.lastBackupTime)}',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'backup':
                                    bs.runBackup([folder.id]);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const BackupProgressPage(),
                                      ),
                                    );
                                  case 'remove':
                                    bs.removeFolder(folder.id);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'backup',
                                    child: ListTile(
                                      leading: Icon(Icons.backup),
                                      title: Text('Backup Now'),
                                      dense: true,
                                    )),
                                const PopupMenuItem(
                                    value: 'remove',
                                    child: ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Remove Backup'),
                                      dense: true,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTime(int ts) {
    if (ts == 0) return 'Never';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
