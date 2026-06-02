import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';

class ZipEntry {
  final String name;
  final String path;
  final int size;
  final bool isFile;
  const ZipEntry({required this.name, required this.path, required this.size, required this.isFile});
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class ZipContentSheet extends StatelessWidget {
  final String zipFileName;
  final List<ZipEntry> entries;
  const ZipContentSheet({super.key, required this.zipFileName, required this.entries});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              width: 32, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.unarchive_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.basename(zipFileName),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('${entries.length} files', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: entries.isEmpty
                  ? Center(child: Text('Empty archive', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final ext = p.extension(entry.name).toLowerCase();
                        IconData icon; Color color;
                        if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
                          icon = Icons.image_rounded; color = AppColors.primary;
                        } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) {
                          icon = Icons.videocam_rounded; color = AppColors.accent;
                        } else if (['.mp3', '.wav', '.aac', '.flac'].contains(ext)) {
                          icon = Icons.audiotrack_rounded; color = AppColors.success;
                        } else if (['.pdf'].contains(ext)) {
                          icon = Icons.picture_as_pdf_rounded; color = AppColors.error;
                        } else if (['.zip', '.tar', '.gz', '.rar'].contains(ext)) {
                          icon = Icons.folder_zip_rounded; color = AppColors.textSecondary;
                        } else {
                          icon = Icons.insert_drive_file_rounded; color = AppColors.textSecondary;
                        }

                        return ListTile(
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(icon, size: 20, color: color),
                          ),
                          title: Text(p.basename(entry.name), maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                          subtitle: Text(p.dirname(entry.name).isEmpty ? '' : p.dirname(entry.name),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                          trailing: Text(formatFileSize(entry.size),
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                          onTap: () async {
                            try {
                              final result = await OpenFilex.open(entry.path);
                              if (result.type != ResultType.done && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not open: ${result.message}')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
