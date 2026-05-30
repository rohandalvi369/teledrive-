import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/file_service.dart';
import '../models/drive_folder.dart';
import '../theme/app_theme.dart';

class MultiUploadSheet extends StatefulWidget {
  final FileService fs;
  final DriveFolder folder;
  final List<PlatformFile> files;
  const MultiUploadSheet({required this.fs, required this.folder, required this.files});

  @override
  State<MultiUploadSheet> createState() => _MultiUploadSheetState();
}

class _MultiUploadSheetState extends State<MultiUploadSheet> {
  final Map<int, double> _progress = {};
  int _completed = 0;
  int _failed = 0;
  bool _done = false;

  @override
  void initState() { super.initState(); _startUploads(); }

  Future<void> _startUploads() async {
    for (int i = 0; i < widget.files.length; i++) {
      final file = widget.files[i];
      try {
        final tempDir = Directory.systemTemp.createTempSync('multi_upload_');
        final destPath = '${tempDir.path}/${file.name}';
        if (file.bytes != null) {
          await File(destPath).writeAsBytes(file.bytes!);
        } else if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          await File(destPath).writeAsBytes(bytes);
        } else {
          setState(() => _failed++);
          continue;
        }
        widget.fs.startUploadTracking(file.name);
        setState(() => _progress[i] = 0);
        await widget.fs.uploadFile(widget.folder, destPath);
        setState(() { _progress[i] = 1.0; _completed++; });
      } catch (e) { setState(() { _progress[i] = -1; _failed++; }); }
    }
    if (mounted) { setState(() => _done = true); await Future.delayed(const Duration(seconds: 1)); if (mounted) Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.files.length;
    final pct = total > 0 ? (_completed + _failed) / total : 0.0;
    return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(_done ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
            color: _done ? AppColors.success : AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(_done ? 'Upload complete' : 'Uploading ${widget.files.length} files...',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: _done ? 1.0 : pct, minHeight: 4,
            backgroundColor: AppColors.surfaceElevated, color: AppColors.primary),
      ),
      const SizedBox(height: 8),
      Text('$_completed done · $_failed failed · ${total - _completed - _failed} remaining',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 12),
      SizedBox(height: 160, child: ListView.separated(itemCount: widget.files.length, separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final file = widget.files[index]; final progress = _progress[index];
          return ListTile(dense: true, leading: Icon(
            progress == 1.0 ? Icons.check_circle_rounded : progress == -1 ? Icons.error_rounded : Icons.hourglass_empty_rounded,
            size: 18,
            color: progress == 1.0 ? AppColors.success : progress == -1 ? AppColors.error : AppColors.textSecondary),
            title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
            trailing: progress != null && progress >= 0
                ? SizedBox(width: 60, child: LinearProgressIndicator(value: progress, minHeight: 4,
                    backgroundColor: AppColors.surfaceElevated, color: AppColors.primary))
                : progress == -1 ? const Icon(Icons.error_rounded, size: 16, color: AppColors.error) : null);
        },
      )),
    ]));
  }
}
