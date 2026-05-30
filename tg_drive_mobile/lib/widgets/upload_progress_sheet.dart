import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/telegram_service.dart';
import '../services/file_service.dart';
import '../models/drive_folder.dart';
import '../theme/app_theme.dart';

class UploadProgressSheet extends StatefulWidget {
  final FileService fs;
  final DriveFolder folder;
  final String path;
  const UploadProgressSheet({required this.fs, required this.folder, required this.path});

  @override
  State<UploadProgressSheet> createState() => _UploadProgressSheetState();
}

class _UploadProgressSheetState extends State<UploadProgressSheet> {
  bool _completed = false;
  String? _error;

  @override
  void initState() { super.initState(); _startUpload(); }

  Future<void> _startUpload() async {
    try {
      await widget.fs.uploadFile(widget.folder, widget.path);
      if (mounted) { setState(() => _completed = true); await Future.delayed(const Duration(seconds: 1)); if (mounted) Navigator.pop(context); }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final fileName = widget.path.split('/').last;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          _completed ? Icons.check_circle_rounded : _error != null ? Icons.error_rounded : Icons.cloud_upload_rounded,
          size: 48,
          color: _completed ? AppColors.success : _error != null ? AppColors.error : AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(_completed ? 'Upload complete' : _error != null ? 'Upload failed' : 'Uploading...',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 8),
        Text(fileName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 16),
        if (_error == null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _completed ? 1.0 : telegram.uploadProgress,
              minHeight: 4,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.primary,
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.error), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 8),
        Text(_completed ? '100%' : _error != null ? '' : '${(telegram.uploadProgress * 100).toInt()}%',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
      ]),
    );
  }
}
