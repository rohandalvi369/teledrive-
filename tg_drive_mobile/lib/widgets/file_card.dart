import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/drive_file.dart';
import '../theme/app_theme.dart';

class FileCard extends StatelessWidget {
  final DriveFile file;
  final VoidCallback onTap;

  const FileCard({super.key, required this.file, required this.onTap});

  (IconData, Color) _getIconAndColor() {
    if (file.mimeType.startsWith('image/')) return (Icons.image, AppColors.fileImage);
    if (file.mimeType.startsWith('video/')) return (Icons.videocam, AppColors.fileVideo);
    if (file.mimeType.startsWith('audio/')) return (Icons.music_note, AppColors.fileAudio);
    if (file.mimeType.startsWith('text/')) return (Icons.description, AppColors.fileDoc);
    if (file.mimeType.contains('pdf')) return (Icons.picture_as_pdf, AppColors.filePdf);
    if (file.mimeType.contains('zip') || file.mimeType.contains('rar') || file.mimeType.contains('tar')) {
      return (Icons.folder_zip, AppColors.fileArchive);
    }
    return (Icons.insert_drive_file, AppColors.textSecondary);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _getIconAndColor();
    final showThumbnail = file.thumbnailBase64 != null && file.thumbnailBase64!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: showThumbnail ? null : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: showThumbnail
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(file.thumbnailBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(icon, size: 22, color: color),
                        ),
                      )
                    : Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatSize(file.size)} · ${_formatDate(file.date)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
