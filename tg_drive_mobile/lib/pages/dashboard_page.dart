import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:archive/archive.dart';
import '../services/telegram_service.dart';
import '../services/file_service.dart';
import '../services/api_service.dart';
import '../services/trash_service.dart';
import '../models/drive_folder.dart';
import '../models/drive_file.dart';
import '../widgets/shimmer_list.dart';
import '../widgets/cloud_painter.dart';
import '../widgets/section_header.dart';
import '../widgets/folder_picker_sheet.dart';
import '../widgets/multi_upload_sheet.dart';
import '../widgets/upload_progress_sheet.dart';
import '../widgets/download_progress_sheet.dart';
import '../widgets/zip_content_sheet.dart';
import '../theme/app_theme.dart';
import 'image_preview_page.dart';
import 'video_preview_page.dart';
import 'audio_preview_page.dart';
import 'pdf_viewer_page.dart';
import 'backup_setup_page.dart';
import 'trash_page.dart';
import 'settings_page.dart';

enum _SortMode { defaultOrder, newest, oldest, largest, smallest, nameAZ, nameZA }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;
  _SortMode _sortMode = _SortMode.newest;
  final _scrollController = ScrollController();
  bool _isScrolledDown = false;

  bool _multiSelectMode = false;
  final Set<DriveFile> _selectedFiles = {};

  Map<String, dynamic>? _stats;
  List<DriveFile> _recents = [];
  bool _recentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _scrollController.addListener(() {
      final scrolled = _scrollController.offset > 20;
      if (scrolled != _isScrolledDown) setState(() => _isScrolledDown = scrolled);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fs = context.read<FileService>();
      fs.fetchFolders();
      _loadStats();
      _loadRecents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  Future<void> _loadStats() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {
      context.read<ApiService>().serverReachable = true;
    }
  }

  Future<void> _loadRecents() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getRecents();
      if (mounted) {
        setState(() {
          _recents = data.map((j) => DriveFile(
            messageId: (j['messageId'] as num).toInt(),
            docId: j['docId'] as String? ?? '',
            fileName: j['fileName'] as String? ?? 'unknown',
            mimeType: j['mimeType'] as String? ?? '',
            size: (j['size'] as num?)?.toInt() ?? 0,
            date: (j['date'] as num?)?.toInt() ?? 0,
            fileId: (j['fileId'] as num?)?.toInt() ?? 0,
            duration: (j['duration'] as num?)?.toInt() ?? 0,
          )).toList();
          _recentsLoaded = true;
        });
      }
    } catch (_) {
      context.read<ApiService>().serverReachable = true;
      if (mounted) setState(() => _recentsLoaded = true);
    }
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedFiles.clear();
    });
  }

  void _toggleSelect(DriveFile file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
        if (_selectedFiles.isEmpty) _multiSelectMode = false;
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  void _enterMultiSelect(DriveFile file) {
    setState(() {
      _multiSelectMode = true;
      _selectedFiles.add(file);
    });
  }


  List<DriveFile> _applySearch(List<DriveFile> files) {
    if (_searchQuery.isEmpty) return files;
    final q = _searchQuery.toLowerCase();
    return files.where((f) => f.fileName.toLowerCase().contains(q)).toList();
  }

  List<DriveFile> _applySort(List<DriveFile> files) {
    if (_sortMode == _SortMode.defaultOrder) return files;
    final sorted = List<DriveFile>.from(files);
    switch (_sortMode) {
      case _SortMode.defaultOrder: break;
      case _SortMode.newest: sorted.sort((a, b) => b.date.compareTo(a.date));
      case _SortMode.oldest: sorted.sort((a, b) => a.date.compareTo(b.date));
      case _SortMode.largest: sorted.sort((a, b) => b.size.compareTo(a.size));
      case _SortMode.smallest: sorted.sort((a, b) => a.size.compareTo(b.size));
      case _SortMode.nameAZ: sorted.sort((a, b) => a.fileName.compareTo(b.fileName));
      case _SortMode.nameZA: sorted.sort((a, b) => b.fileName.compareTo(a.fileName));
    }
    return sorted;
  }


  Future<String> _copyToTemp(PlatformFile file) async {
    final dir = Directory.systemTemp.createTempSync('upload_');
    final destPath = '${dir.path}/${file.name}';
    if (file.path != null && !file.path!.startsWith('content://')) {
      await File(file.path!).copy(destPath);
    } else if (file.path != null) {
      final src = File(file.path!);
      await src.copy(destPath);
    } else if (file.bytes != null) {
      await File(destPath).writeAsBytes(file.bytes!);
    } else {
      throw Exception('Cannot access file: ${file.name}');
    }
    return destPath;
  }

  Future<void> _pickAndUpload(FileService fs) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    final folder = fs.activeFolder ?? fs.folders.first;
    if (folder.chatId == null) return;
    if (result.files.length == 1) {
      final path = await _copyToTemp(result.files.first);
      if (!mounted) return;
      await _showUploadProgress(context, fs, folder, path);
      if (!mounted) return;
      final curFolder = fs.activeFolder;
      if (curFolder != null) await fs.fetchFiles(curFolder);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload complete'), duration: Duration(seconds: 2)),
      );
      return;
    }
    await _showMultiUploadSheet(context, fs, folder, result.files);
    if (!mounted) return;
    final curFolder = fs.activeFolder;
    if (curFolder != null) await fs.fetchFiles(curFolder);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload complete'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _showMultiUploadSheet(
    BuildContext ctx, FileService fs, DriveFolder folder, List<PlatformFile> files,
  ) async {
    await showModalBottomSheet(
      context: ctx, enableDrag: false, isDismissible: false,
      builder: (_) => MultiUploadSheet(fs: fs, folder: folder, files: files),
    );
  }

  Future<void> _showUploadProgress(
    BuildContext ctx, FileService fs, DriveFolder folder, String path,
  ) async {
    await showModalBottomSheet(
      context: ctx, enableDrag: false, isDismissible: false,
      builder: (_) => UploadProgressSheet(fs: fs, folder: folder, path: path),
    );
  }


  Future<void> _downloadAndPreview(
    BuildContext ctx, FileService fs, DriveFile file, {
    List<DriveFile>? imageList, int imageIndex = 0,
  }) async {
    if (file.isImage && imageList != null && imageList.length > 1) {
      if (!file.isDownloaded) {
        final path = await showModalBottomSheet<String>(
          context: ctx, enableDrag: false, isDismissible: false,
          builder: (_) => DownloadProgressSheet(fs: fs, file: file),
        );
        if (path == null || !mounted) return;
      }
      if (!mounted) return;
      Navigator.push(ctx,
        MaterialPageRoute(builder: (_) => ImagePreviewPage(images: imageList, initialIndex: imageIndex)),
      );
      return;
    }
    if (file.isDownloaded) { _openFile(ctx, file); return; }
    final path = await showModalBottomSheet<String>(
      context: ctx, enableDrag: false, isDismissible: false,
      builder: (_) => DownloadProgressSheet(fs: fs, file: file),
    );
    if (path != null && mounted) { file.localPath = path; _openFile(ctx, file); }
  }

  void _openFile(BuildContext ctx, DriveFile file) {
    final path = file.localPath;
    if (path == null || path.isEmpty) return;
    if (file.mimeType.startsWith('image/')) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => ImagePreviewPage(images: [file], initialIndex: 0)));
    } else if (file.mimeType.startsWith('video/')) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => VideoPreviewPage(path: path, fileName: file.fileName)));
    } else if (file.mimeType.startsWith('audio/')) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => AudioPreviewPage(path: path, fileName: file.fileName)));
    } else if (file.mimeType.contains('pdf')) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => PdfViewerPage(path: path, fileName: file.fileName)));
    } else {
      OpenFilex.open(path);
    }
  }


  Future<void> _downloadSelected(FileService fs) async {
    for (final file in _selectedFiles) {
      if (!file.isDownloaded) await fs.downloadFile(file);
    }
    _exitMultiSelect();
  }

  Future<void> _moveToTrashSelected(FileService fs) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Move to Trash'),
        content: Text('Move ${_selectedFiles.length} file(s) to trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final files = _selectedFiles.toList();
    _exitMultiSelect();
    try {
      final ts = context.read<TrashService>();
      final chatId = fs.activeFolder?.chatId;
      if (chatId != null) {
        await ts.moveToTrash(files, chatId.toString(), '');
      }
    } catch (e) {
      debugPrint('Trash API failed (expected without accessHash): $e');
    }
    try {
      await fs.deleteMessages(files);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${files.length} file(s) moved to trash')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
    if (fs.activeFolder != null) fs.fetchFiles(fs.activeFolder!);
  }

  Future<void> _moveSelected(FileService fs) async {
    final targetFolder = await showModalBottomSheet<DriveFolder>(
      context: context,
      builder: (ctx) => FolderPickerSheet(folders: fs.folders.where((f) => f.id != fs.activeFolder?.id).toList()),
    );
    if (targetFolder == null) return;
    final files = _selectedFiles.toList();
    _exitMultiSelect();
    try {
      for (final file in files) {
        await fs.forwardMessage(file, targetFolder);
      }
      await fs.deleteMessages(files);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${files.length} file(s) moved to ${targetFolder.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Move failed: $e')));
      }
    }
    if (fs.activeFolder != null) fs.fetchFiles(fs.activeFolder!);
  }

  Future<void> _createZipSelected(FileService fs) async {
    for (final file in _selectedFiles) {
      if (!file.isDownloaded) await fs.downloadFile(file);
    }
    try {
      final archive = await _createZipFromFiles(_selectedFiles.toList());
      if (archive != null && fs.activeFolder != null) {
        await fs.uploadFile(fs.activeFolder!, archive.path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zip failed: $e')));
    }
    _exitMultiSelect();
    if (fs.activeFolder != null) fs.fetchFiles(fs.activeFolder!);
  }

  Future<File?> _createZipFromFiles(List<DriveFile> files) async {
    try {
      final dir = Directory.systemTemp.createTempSync('zip_');
      final zipPath = '${dir.path}/archive.zip';
      final archive = Archive();
      for (final file in files) {
        if (file.localPath != null) {
          final bytes = File(file.localPath!).readAsBytesSync();
          final archiveFile = ArchiveFile(file.fileName, bytes.length, bytes);
          archive.addFile(archiveFile);
        }
      }
      final encoded = ZipEncoder().encode(archive);
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(encoded);
      return zipFile;
    } catch (e) {
      debugPrint('Zip creation error: $e');
      return null;
    }
  }

  Future<void> _extractZip(BuildContext ctx, FileService fs, DriveFile file) async {
    if (!file.isDownloaded) {
      final path = await showModalBottomSheet<String>(
        context: ctx, enableDrag: false, isDismissible: false,
        builder: (_) => DownloadProgressSheet(fs: fs, file: file),
      );
      if (path == null || !mounted) return;
      file.localPath = path;
    }
    if (file.localPath == null) return;

    try {
      final bytes = await File(file.localPath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final extractDir = Directory.systemTemp.createTempSync('extract_${file.messageId}_');
      final extracted = <ZipEntry>[];

      for (final entry in archive) {
        if (entry.isFile) {
          final outPath = '${extractDir.path}/${entry.name}';
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          await outFile.writeAsBytes(entry.content as List<int>);
          extracted.add(ZipEntry(name: entry.name, path: outPath, size: entry.size, isFile: true));
        }
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: ctx, isScrollControlled: true,
        builder: (_) => ZipContentSheet(zipFileName: file.fileName, entries: extracted),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Extract failed: $e')));
      }
    }
  }


  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}/${date.month}/${date.year}';
  }

  String get _sortLabel {
    switch (_sortMode) {
      case _SortMode.defaultOrder: return 'Default';
      case _SortMode.nameAZ: return 'A-Z';
      case _SortMode.nameZA: return 'Z-A';
      case _SortMode.newest: return 'Newest';
      case _SortMode.oldest: return 'Oldest';
      case _SortMode.largest: return 'Largest';
      case _SortMode.smallest: return 'Smallest';
    }
  }

  String _formatDuration(int secs) {
    final min = (secs ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }


  @override
  Widget build(BuildContext context) {
    final fs = context.watch<FileService>();
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: _multiSelectMode
          ? _buildMultiSelectAppBar(fs, theme)
          : _buildGlassAppBar(fs),
      drawer: _buildDrawer(context, fs, theme),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: _buildBody(context, fs, theme),
        ),
      ),
      floatingActionButton: _buildFAB(fs),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(FileService fs) {
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.8),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: Colors.transparent),
        ),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Text(fs.activeFolder?.title ?? 'TeleDrive',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          tooltip: 'Refresh',
          onPressed: () {
            final folder = fs.activeFolder;
            if (folder != null) fs.fetchFiles(folder);
          },
        ),
        PopupMenuButton<_SortMode>(
          icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary),
          tooltip: 'Sort',
          onSelected: (v) => setState(() => _sortMode = v),
          initialValue: _sortMode,
          itemBuilder: (_) => [
            PopupMenuItem(value: _SortMode.defaultOrder, child: Text('Default', style: _sortMode == _SortMode.defaultOrder ? const TextStyle(fontWeight: FontWeight.bold) : null)),
            PopupMenuItem(value: _SortMode.nameAZ, child: Text('Name A-Z', style: _sortMode == _SortMode.nameAZ ? const TextStyle(fontWeight: FontWeight.bold) : null)),
            PopupMenuItem(value: _SortMode.nameZA, child: Text('Name Z-A', style: _sortMode == _SortMode.nameZA ? const TextStyle(fontWeight: FontWeight.bold) : null)),
            PopupMenuItem(value: _SortMode.newest, child: Text('Newest', style: _sortMode == _SortMode.newest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
            PopupMenuItem(value: _SortMode.oldest, child: Text('Oldest', style: _sortMode == _SortMode.oldest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
            PopupMenuItem(value: _SortMode.largest, child: Text('Largest', style: _sortMode == _SortMode.largest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
            PopupMenuItem(value: _SortMode.smallest, child: Text('Smallest', style: _sortMode == _SortMode.smallest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
          ],
        ),
      ],
      bottom: fs.loading && fs.files.isEmpty ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                              onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                          : null,
                      filled: true, fillColor: Colors.transparent, isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildMultiSelectAppBar(FileService fs, ThemeData theme) {
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.8),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: Colors.transparent),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: _exitMultiSelect,
      ),
      title: Text('${_selectedFiles.length} selected',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      actions: [
        IconButton(icon: const Icon(Icons.download_rounded), tooltip: 'Download', color: AppColors.textSecondary,
          onPressed: _selectedFiles.isEmpty ? null : () => _downloadSelected(fs)),
        IconButton(icon: const Icon(Icons.drive_file_move_rounded), tooltip: 'Move', color: AppColors.textSecondary,
          onPressed: _selectedFiles.isEmpty ? null : () => _moveSelected(fs)),
        IconButton(icon: const Icon(Icons.folder_zip_rounded), tooltip: 'Create Zip', color: AppColors.textSecondary,
          onPressed: _selectedFiles.length < 2 ? null : () => _createZipSelected(fs)),
        IconButton(icon: const Icon(Icons.delete_rounded, color: AppColors.error), tooltip: 'Move to Trash',
          onPressed: _selectedFiles.isEmpty ? null : () => _moveToTrashSelected(fs)),
      ],
    );
  }

  Widget _buildFAB(FileService fs) {
    final telegram = context.watch<TelegramService>();

    if (telegram.isUploading) {
      return SizedBox(
        width: 64, height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64, height: 64,
              child: CircularProgressIndicator(
                value: telegram.uploadProgress,
                strokeWidth: 3,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 24),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!_isScrolledDown)
            Positioned(
              right: 56,
              child: AnimatedOpacity(
                opacity: _isScrolledDown ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.only(left: 24, right: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                    boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 2)],
                  ),
                  alignment: Alignment.center,
                  child: Text('Upload', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
              boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 2)],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: fs.activeFolder != null ? () => _pickAndUpload(fs) : null,
                child: const Center(
                  child: Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDrawer(BuildContext context, FileService fs, ThemeData theme) {
    final telegram = context.read<TelegramService>();

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Container(
        color: AppColors.bg.withValues(alpha: 0.96),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.accent.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                        boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 16, spreadRadius: 2)],
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('TeleDrive User', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Connected', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                ),


                if (_stats != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: _buildStorageRing(theme),
                  ),
                  const Divider(indent: 20, endIndent: 20),
                ],


                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text('HOME', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1.2)),
                ),
                ...fs.folders.map((folder) {
                  final isSaved = folder.type == 'saved';
                  final isActive = fs.activeFolder?.id == folder.id;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: isActive ? AppColors.primary : Colors.transparent, width: 3),
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(isSaved ? Icons.save_rounded : Icons.folder_rounded,
                          color: isActive ? AppColors.primary : AppColors.textSecondary, size: 22),
                      title: Text(folder.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : AppColors.textSecondary)),
                      dense: true,
                      onTap: () { fs.fetchFiles(folder); Navigator.pop(context); },
                      onLongPress: isSaved ? null : () => _showFolderOptions(context, fs, folder),
                    ),
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
                  title: Text('New Folder', style: GoogleFonts.inter(fontSize: 14, color: AppColors.primary)),
                  dense: true,
                  onTap: () { Navigator.pop(context); _showCreateFolderDialog(context, fs); },
                ),

                const Divider(indent: 20, endIndent: 20),


                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text('QUICK LINKS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1.2)),
                ),
                _drawerItem(Icons.history_rounded, 'Recent Files', () { Navigator.pop(context); _tabController.animateTo(5); }),
                _drawerItem(Icons.backup_rounded, 'Auto Backup', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSetupPage())); }),
                _drawerItem(Icons.delete_outline_rounded, 'Trash', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashPage())); }, color: AppColors.error),

                const Divider(indent: 20, endIndent: 20),


                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text('MORE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1.2)),
                ),
                _drawerItem(Icons.settings_rounded, 'Settings', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())); }),
                _drawerItem(Icons.logout_rounded, 'Sign out', () { Navigator.pop(context); telegram.logout(); }, color: AppColors.error),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary, size: 22),
      title: Text(title, style: GoogleFonts.inter(fontSize: 14,
          color: color ?? AppColors.textSecondary, fontWeight: FontWeight.w500)),
      dense: true,
      onTap: onTap,
    );
  }

  Widget _buildStorageRing(ThemeData theme) {
    if (_stats == null) return const SizedBox.shrink();
    final totalFiles = _stats!['totalFiles'] ?? 0;
    final totalSize = _stats!['totalSize'] ?? 0;
    final cats = _stats!['categories'] as Map<String, dynamic>? ?? {};

    final items = ['images', 'videos', 'audio', 'documents'];
    final counts = items.map((k) => (cats[k] as num?)?.toInt() ?? 0).toList();
    final total = counts.fold<int>(0, (s, c) => s + c);

    return Row(
      children: [
        SizedBox(
          width: 56, height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56, height: 56,
                child: CircularProgressIndicator(
                  value: total > 0 ? 1.0 : 0,
                  strokeWidth: 4,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              Text('${_formatNumber(totalFiles)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_formatNumber(totalFiles)} files', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
            const SizedBox(height: 2),
            Text(_formatSize(totalSize), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }


  void _showCreateFolderDialog(BuildContext context, FileService fs) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('New Folder', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(hintText: 'Channel name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
        FilledButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { fs.createFolder(ctrl.text.trim()); Navigator.pop(ctx); } }, child: const Text('Create')),
      ],
    ));
  }

  void _showFolderOptions(BuildContext context, FileService fs, DriveFolder folder) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.edit_rounded, color: AppColors.textSecondary), title: Text('Rename', style: GoogleFonts.inter(color: Colors.white)),
        onTap: () { Navigator.pop(ctx); _showRenameDialog(context, fs, folder); }),
      ListTile(leading: const Icon(Icons.delete_rounded, color: AppColors.error), title: Text('Delete', style: GoogleFonts.inter(color: AppColors.error)),
        onTap: () { Navigator.pop(ctx); _showDeleteConfirm(context, fs, folder); }),
    ])));
  }

  void _showRenameDialog(BuildContext context, FileService fs, DriveFolder folder) {
    final ctrl = TextEditingController(text: folder.title);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Rename Folder', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        decoration: const InputDecoration(hintText: 'New name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
        FilledButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { fs.renameFolder(folder, ctrl.text.trim()); Navigator.pop(ctx); } }, child: const Text('Rename')),
      ],
    ));
  }

  void _showDeleteConfirm(BuildContext context, FileService fs, DriveFolder folder) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Delete Folder', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      content: Text('Are you sure you want to delete "${folder.title}"? This will permanently delete the channel and all its messages.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () { fs.deleteFolder(folder); Navigator.pop(ctx); },
          child: const Text('Delete'),
        ),
      ],
    ));
  }


  Widget _buildBody(BuildContext context, FileService fs, ThemeData theme) {
    final api = context.watch<ApiService>();

    if (fs.error != null && fs.files.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
        ),
        const SizedBox(height: 16),
        Text(fs.error!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _glassButton('Retry', () { if (fs.activeFolder != null) fs.fetchFiles(fs.activeFolder!); }),
      ]));
    }
    if (fs.loading && fs.files.isEmpty) return const ShimmerList();
    if (!fs.loading && fs.files.isEmpty) {
      return _emptyState(context);
    }

    final activeFiles = _applySort(_applySearch(fs.files));
    final totalSize = activeFiles.fold<int>(0, (s, f) => s + f.size);

    return Column(
      children: [
        if (!api.serverReachable)
          Container(
            width: double.infinity,
            color: AppColors.error.withValues(alpha: 0.9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Server unreachable — some features may not work',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
              ),
            ]),
          ),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
            tabs: [
              _buildPillTab(Icons.all_inclusive_rounded, 'All'),
              _buildPillTab(Icons.image_rounded, 'Images'),
              _buildPillTab(Icons.videocam_rounded, 'Videos'),
              _buildPillTab(Icons.audiotrack_rounded, 'Audio'),
              _buildPillTab(Icons.description_rounded, 'Docs'),
              _buildPillTab(Icons.history_rounded, 'Recent'),
            ],
          ),
        ),

        if (activeFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(children: [
              Text('${activeFiles.length} files',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              Text('· ${_formatSize(totalSize)}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              if (_sortMode != _SortMode.defaultOrder)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _sortMode = _SortMode.defaultOrder),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_sortLabel, style: GoogleFonts.inter(fontSize: 11, color: AppColors.primary)),
                      const SizedBox(width: 4),
                      const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                    ]),
                  ),
                ),
            ]),
          ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllTab(context, fs, _applySort(_applySearch(fs.files)), theme),
              _buildImagesTab(context, fs, _applySort(_applySearch(fs.images))),
              _buildListTab(context, fs, _applySort(_applySearch(fs.videos)), icon: Icons.videocam_rounded, color: AppColors.accent),
              _buildListTab(context, fs, _applySort(_applySearch(fs.audioFiles)), icon: Icons.audiotrack_rounded, color: AppColors.success),
              _buildListTab(context, fs, _applySort(_applySearch(fs.documents)), icon: Icons.insert_drive_file_rounded, color: AppColors.textSecondary),
              _buildRecentsTab(context, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillTab(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Tab(child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      )),
    );
  }

  Widget _glassButton(String text, VoidCallback onPressed) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary)),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildStatsCard(ThemeData theme) {
    if (_stats == null) return const SizedBox.shrink();
    final totalFiles = _stats!['totalFiles'] ?? 0;
    final totalSize = _stats!['totalSize'] ?? 0;
    final cats = _stats!['categories'] as Map<String, dynamic>? ?? {};
    final sizes = _stats!['sizes'] as Map<String, dynamic>? ?? {};

    final items = ['images', 'videos', 'audio', 'documents'];
    final colors = [AppColors.primary, AppColors.accent, AppColors.success, AppColors.textSecondary];
    final icons = [Icons.image_rounded, Icons.videocam_rounded, Icons.audiotrack_rounded, Icons.insert_drive_file_rounded];
    final totalCatCount = items.fold<int>(0, (s, k) => s + ((cats[k] as num?)?.toInt() ?? 0));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${_formatNumber(totalFiles)} files',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 12),
            Text(_formatSize(totalSize),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 10),
          Container(
            height: 6,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3)),
            child: Row(children: items.asMap().entries.map((e) {
              final count = (cats[e.value] as num?)?.toInt() ?? 0;
              final flex = totalCatCount > 0 ? count : 0;
              return flex > 0
                  ? Expanded(flex: flex, child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        color: colors[e.key],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ))
                  : const SizedBox.shrink();
            }).toList()),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 6, children: items.asMap().entries.map((e) {
            final count = (cats[e.value] as num?)?.toInt() ?? 0;
            final sz = (sizes[e.value] as num?)?.toInt() ?? 0;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icons[e.key], size: 14, color: colors[e.key]),
              const SizedBox(width: 6),
              Text('${_formatNumber(count)} · ${_formatSize(sz)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ]);
          }).toList()),
        ]),
      ),
    );
  }


  Widget _buildAllTab(BuildContext context, FileService fs, List<DriveFile> files, ThemeData theme) {
    final images = files.where((f) => f.isImage).toList();
    final videos = files.where((f) => f.isVideo).toList();
    final audio = files.where((f) => f.isAudio).toList();
    final docs = files.where((f) => !f.isImage && !f.isVideo && !f.isAudio).toList();

    final sections = <String, List<DriveFile>>{};
    if (images.isNotEmpty) sections['Images'] = images;
    if (videos.isNotEmpty) sections['Videos'] = videos;
    if (audio.isNotEmpty) sections['Audio'] = audio;
    if (docs.isNotEmpty) sections['Documents'] = docs;

    return RefreshIndicator(
      onRefresh: () async { if (fs.activeFolder != null) await fs.fetchFiles(fs.activeFolder!); },
      color: AppColors.primary,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildStatsCard(theme),
          ...sections.entries.expand((entry) => [
            SectionHeader(title: entry.key, count: entry.value.length),
            ...entry.value.map((f) => _buildFileRow(context, fs, f)),
          ]),
          if (sections.isEmpty) _emptyState(context),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildImagesTab(BuildContext context, FileService fs, List<DriveFile> files) {
    if (files.isEmpty) return _emptyState(context);
    return RefreshIndicator(
      onRefresh: () async { if (fs.activeFolder != null) await fs.fetchFiles(fs.activeFolder!); },
      color: AppColors.primary,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1),
        itemCount: files.length,
        itemBuilder: (context, index) => _buildImageGridItem(context, fs, files[index], files, index),
      ),
    );
  }

  Widget _buildListTab(BuildContext context, FileService fs, List<DriveFile> files, {required IconData icon, required Color color}) {
    if (files.isEmpty) return _emptyState(context);
    return RefreshIndicator(
      onRefresh: () async { if (fs.activeFolder != null) await fs.fetchFiles(fs.activeFolder!); },
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: files.length,
        itemBuilder: (context, index) => _buildListItem(context, fs, files[index], icon: icon, color: color),
      ),
    );
  }

  Widget _buildRecentsTab(BuildContext context, ThemeData theme) {
    if (!_recentsLoaded) {
      return RefreshIndicator(
        onRefresh: _emptyRefresh,
        color: AppColors.primary,
        child: const SizedBox.expand(child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      );
    }
    if (_recents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRecents,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.history_rounded, size: 40, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text('No recent files', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRecents,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: _recents.length,
        itemBuilder: (context, index) {
          final file = _recents[index];
          IconData icon; Color color;
          if (file.isImage) { icon = Icons.image_rounded; color = AppColors.primary; }
          else if (file.isVideo) { icon = Icons.videocam_rounded; color = AppColors.accent; }
          else if (file.isAudio) { icon = Icons.audiotrack_rounded; color = AppColors.success; }
          else { icon = Icons.insert_drive_file_rounded; color = AppColors.textSecondary; }
          return _buildCard(
            child: ListTile(
              leading: _fileIcon(icon, color),
              title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              subtitle: Text('${_formatSize(file.size)} · ${_formatDate(file.date)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _emptyRefresh() async {}


  Widget _buildImageGridItem(BuildContext context, FileService fs, DriveFile file, List<DriveFile> allImages, int index) {
    final selected = _selectedFiles.contains(file);

    Widget child;
    if (file.isDownloaded && file.localPath != null) {
      child = Image.file(File(file.localPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder(context));
    } else if (file.thumbnailBase64 != null) {
      child = Image.memory(base64Decode(file.thumbnailBase64!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder(context));
    } else {
      child = _imagePlaceholder(context);
    }

    return AnimatedScale(
      scale: selected ? 0.92 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: () {
          if (_multiSelectMode) _toggleSelect(file);
          else _downloadAndPreview(context, fs, file, imageList: allImages, imageIndex: index);
        },
        onLongPress: () => _enterMultiSelect(file),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'image_${file.docId}', child: child),
              if (selected)
                Container(color: AppColors.primary.withValues(alpha: 0.3),
                  child: const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 24))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Center(child: Icon(Icons.image_rounded, size: 28, color: AppColors.textSecondary)),
    );
  }

  Widget _buildFileRow(BuildContext context, FileService fs, DriveFile file) {
    IconData icon; Color color;
    switch (file.categoryIcon) {
      case 'image': icon = Icons.image_rounded; color = AppColors.primary; break;
      case 'video': icon = Icons.videocam_rounded; color = AppColors.accent; break;
      case 'audio': icon = Icons.audiotrack_rounded; color = AppColors.success; break;
      default: icon = Icons.insert_drive_file_rounded; color = AppColors.textSecondary;
    }
    return _buildListItem(context, fs, file, icon: icon, color: color);
  }

  Widget _buildListItem(BuildContext context, FileService fs, DriveFile file, {required IconData icon, required Color color}) {
    final selected = _selectedFiles.contains(file);

    return _buildCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () { if (_multiSelectMode) _toggleSelect(file); else _downloadAndPreview(context, fs, file); },
        onLongPress: () => _enterMultiSelect(file),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              if (_multiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              _fileIcon(icon, color),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(file.fileName,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text(_formatSize(file.size), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  Text(' · ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  Text(_formatDate(file.date), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  if (file.duration > 0) ...[
                    Text(' · ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                    Text(_formatDuration(file.duration), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ]),
              ])),
              if (!_multiSelectMode)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (file.isZip)
                    IconButton(
                      icon: const Icon(Icons.unarchive_rounded, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: 'Extract',
                      onPressed: () => _extractZip(context, fs, file),
                    ),
                ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _fileIcon(IconData icon, Color color) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsets margin = EdgeInsets.zero}) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 10, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _emptyState(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), shape: BoxShape.circle),
        child: CustomPaint(
          size: const Size(100, 100),
          painter: CloudPainter(),
        ),
      ),
      const SizedBox(height: 16),
      Text(_searchQuery.isNotEmpty ? 'No matching files' : 'No files here yet',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
      const SizedBox(height: 8),
      Text(_searchQuery.isNotEmpty ? 'Try a different search' : 'Upload your first file to get started',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
      if (_searchQuery.isEmpty) ...[
        const SizedBox(height: 20),
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
            boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 20, spreadRadius: 1)],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _pickAndUpload(context.read<FileService>()),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      ],
    ]));
  }
}
