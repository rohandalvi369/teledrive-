import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';

class BackupProgressPage extends StatefulWidget {
  const BackupProgressPage({super.key});

  @override
  State<BackupProgressPage> createState() => _BackupProgressPageState();
}

class _BackupProgressPageState extends State<BackupProgressPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bs = context.read<BackupService>();
      if (!bs.backingUp) {
        bs.runBackup(bs.config.selectedFolderIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bs = context.watch<BackupService>();
    final theme = Theme.of(context);
    final p = bs.progress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Progress'),
        automaticallyImplyLeading: !bs.backingUp,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                p.done
                    ? (p.error != null ? Icons.error : Icons.check_circle)
                    : Icons.cloud_upload,
                size: 72,
                color: p.done
                    ? (p.error != null
                        ? theme.colorScheme.error
                        : Colors.green)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                p.done
                    ? (p.error != null ? 'Backup Failed' : 'Backup Complete')
                    : 'Backing up...',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                p.folderName.isNotEmpty ? p.folderName : 'Preparing...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (!p.done) ...[
                LinearProgressIndicator(value: p.progress),
                const SizedBox(height: 12),
                Text(
                  '${p.completedFiles} / ${p.totalFiles} files',
                  style: theme.textTheme.bodySmall,
                ),
                if (p.currentFile.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.currentFile,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
              if (p.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  p.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              if (p.done)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
