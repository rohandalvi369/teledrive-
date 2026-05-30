import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drive_folder.dart';
import '../theme/app_theme.dart';

class FolderPickerSheet extends StatelessWidget {
  final List<DriveFolder> folders;
  const FolderPickerSheet({required this.folders});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Move to folder',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white))),
      if (folders.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No other folders available'))
      else ...folders.map((f) => ListTile(
        leading: Icon(f.type == 'saved' ? Icons.save_rounded : Icons.folder_rounded,
            color: AppColors.textSecondary, size: 22),
        title: Text(f.title, style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
        onTap: () => Navigator.pop(context, f),
      )),
      const SizedBox(height: 8),
    ]));
  }
}
