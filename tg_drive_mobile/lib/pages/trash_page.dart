import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/trash_service.dart';
import '../services/file_service.dart';
import '../widgets/shimmer_list.dart';
import '../theme/app_theme.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = context.watch<TrashService>();
    final fs = context.read<FileService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (ts.trashFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Empty trash',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Empty Trash'),
                    content: const Text(
                        'Permanently delete all files in trash older than 30 days?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Purge'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ts.purge();
                }
              },
            ),
        ],
      ),
      body: _buildBody(context, ts, fs, theme),
    );
  }

  Widget _buildBody(
      BuildContext context, TrashService ts, FileService fs, ThemeData theme) {
    if (ts.loading) return const ShimmerList();

    if (ts.trashFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Trash is empty', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: ts.trashFiles.length,
      itemBuilder: (context, index) {
        final file = ts.trashFiles[index];
        final days = file.duration; // daysUntilPurge passed via duration field
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            leading: Icon(_getIcon(file.mimeType),
                color: _getColor(file.mimeType)),
            title: Text(file.fileName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              'Auto-delete in $days days',
              style: TextStyle(color: days < 3
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.restore),
                  tooltip: 'Restore to Saved Messages',
                  onPressed: () => ts.restore([file.messageId]),
                ),
                IconButton(
                  icon: Icon(Icons.delete_forever,
                      color: theme.colorScheme.error),
                  tooltip: 'Permanently delete',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Forever'),
                        content: Text('Delete "${file.fileName}" permanently?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ts.restore([file.messageId]);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(String mime) {
    if (mime.startsWith('image/')) return Icons.image;
    if (mime.startsWith('video/')) return Icons.videocam;
    if (mime.startsWith('audio/')) return Icons.audiotrack;
    return Icons.insert_drive_file;
  }

  Color _getColor(String mime) {
    if (mime.startsWith('image/')) return AppColors.success;
    if (mime.startsWith('video/')) return AppColors.fileImage;
    if (mime.startsWith('audio/')) return AppColors.fileDoc;
    return AppColors.textSecondary;
  }
}
