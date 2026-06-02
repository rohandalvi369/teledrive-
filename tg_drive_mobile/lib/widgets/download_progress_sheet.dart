import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/telegram_service.dart';
import '../services/file_service.dart';
import '../models/drive_file.dart';
import '../theme/app_theme.dart';

class DownloadProgressSheet extends StatefulWidget {
  final FileService fs;
  final DriveFile file;
  const DownloadProgressSheet({super.key, required this.fs, required this.file});

  @override
  State<DownloadProgressSheet> createState() => _DownloadProgressSheetState();
}

class _DownloadProgressSheetState extends State<DownloadProgressSheet> {
  bool _completed = false;
  String? _error;
  String? _resultPath;

  @override
  void initState() { super.initState(); _startDownload(); }

  Future<void> _startDownload() async {
    try {
      final path = await widget.fs.downloadFile(widget.file);
      if (mounted) {
        if (path != null) {
          _resultPath = path;
          setState(() => _completed = true);
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context, _resultPath);
        } else setState(() => _error = 'Download failed');
      }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          _completed ? Icons.check_circle_rounded : _error != null ? Icons.error_rounded : Icons.cloud_download_rounded,
          size: 48,
          color: _completed ? AppColors.success : _error != null ? AppColors.error : AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(_completed ? 'Download complete' : _error != null ? 'Download failed' : 'Downloading...',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 8),
        Text(widget.file.fileName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 16),
        if (_error == null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _completed ? 1.0 : telegram.downloadProgress,
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
        Text(_completed ? '100%' : _error != null ? '' : '${(telegram.downloadProgress * 100).toInt()}%',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
      ]),
    );
  }
}
