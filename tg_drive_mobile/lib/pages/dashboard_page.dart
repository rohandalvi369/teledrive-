import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../services/telegram_service.dart';
import '../services/file_service.dart';
import '../services/theme_service.dart';
import '../services/api_service.dart';
import '../services/trash_service.dart';
import '../services/favorites_service.dart';
import '../models/drive_folder.dart';
import '../models/drive_file.dart';
import '../widgets/shimmer_list.dart';
import 'image_preview_page.dart';
import 'video_preview_page.dart';
import 'audio_preview_page.dart';
import 'pdf_viewer_page.dart';
import 'backup_setup_page.dart';
import 'trash_page.dart';

enum _SortMode { newest, oldest, largest, smallest, nameAZ }

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

  bool _multiSelectMode = false;
  final Set<DriveFile> _selectedFiles = {};

  Map<String, dynamic>? _stats;
  List<DriveFile> _recents = [];
  bool _recentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fs = context.read<FileService>();
      fs.fetchFolders();
      _loadStats();
      _loadRecents();
      _autoPurge();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
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
      if (mounted) setState(() => _recentsLoaded = true);
    }
  }

  Future<void> _autoPurge() async {
    try {
      final ts = context.read<TrashService>();
      await ts.purge();
    } catch (_) {}
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

  // ─── Search / Sort ────────────────────────────────────────────

  List<DriveFile> _applySearch(List<DriveFile> files) {
    if (_searchQuery.isEmpty) return files;
    final q = _searchQuery.toLowerCase();
    return files.where((f) => f.fileName.toLowerCase().contains(q)).toList();
  }

  List<DriveFile> _applySort(List<DriveFile> files) {
    final sorted = List<DriveFile>.from(files);
    switch (_sortMode) {
      case _SortMode.newest:
        sorted.sort((a, b) => b.date.compareTo(a.date));
      case _SortMode.oldest:
        sorted.sort((a, b) => a.date.compareTo(b.date));
      case _SortMode.largest:
        sorted.sort((a, b) => b.size.compareTo(a.size));
      case _SortMode.smallest:
        sorted.sort((a, b) => a.size.compareTo(b.size));
      case _SortMode.nameAZ:
        sorted.sort((a, b) => a.fileName.compareTo(b.fileName));
    }
    return sorted;
  }

  // ─── Upload ───────────────────────────────────────────────────

  Future<String> _copyToTemp(PlatformFile file) async {
    final dir = Directory.systemTemp.createTempSync('upload_');
    final destPath = '${dir.path}/${file.name}';
    if (file.path != null && !file.path!.startsWith('content://')) {
      await File(file.path!).copy(destPath);
    } else if (file.bytes != null) {
      await File(destPath).writeAsBytes(file.bytes!);
    } else if (file.path != null) {
      final fileBytes = await File(file.path!).readAsBytes();
      await File(destPath).writeAsBytes(fileBytes);
    } else {
      throw Exception('Cannot access file: ${file.name}');
    }
    return destPath;
  }

  Future<void> _pickAndUpload(FileService fs) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty) return;
    final folder = fs.activeFolder ?? fs.folders.first;
    if (folder.chatId == null) return;
    if (result.files.length == 1) {
      final path = await _copyToTemp(result.files.first);
      if (!mounted) return;
      _showUploadProgress(context, fs, folder, path);
      return;
    }
    _showMultiUploadSheet(context, fs, folder, result.files);
  }

  void _showMultiUploadSheet(
    BuildContext ctx,
    FileService fs,
    DriveFolder folder,
    List<PlatformFile> files,
  ) {
    showModalBottomSheet(
      context: ctx,
      enableDrag: false,
      isDismissible: false,
      builder: (_) => _MultiUploadSheet(fs: fs, folder: folder, files: files),
    );
  }

  void _showUploadProgress(
    BuildContext ctx,
    FileService fs,
    DriveFolder folder,
    String path,
  ) {
    showModalBottomSheet(
      context: ctx,
      enableDrag: false,
      isDismissible: false,
      builder: (_) => _UploadProgressSheet(fs: fs, folder: folder, path: path),
    );
  }

  // ─── Download / Preview ───────────────────────────────────────

  Future<void> _downloadAndPreview(
    BuildContext ctx,
    FileService fs,
    DriveFile file, {
    List<DriveFile>? imageList,
    int imageIndex = 0,
  }) async {
    if (file.isImage && imageList != null && imageList.length > 1) {
      if (!file.isDownloaded) {
        final path = await showModalBottomSheet<String>(
          context: ctx,
          enableDrag: false,
          isDismissible: false,
          builder: (_) => _DownloadProgressSheet(fs: fs, file: file),
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
      builder: (_) => _DownloadProgressSheet(fs: fs, file: file),
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

  // ─── Multi-Select Actions ─────────────────────────────────────

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
        title: const Text('Move to Trash'),
        content: Text('Move ${_selectedFiles.length} file(s) to trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final ts = context.read<TrashService>();
      final chatId = fs.activeFolder?.chatId;
      if (chatId == null) return;
      await ts.moveToTrash(_selectedFiles.toList(), chatId.toString(), '');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
    _exitMultiSelect();
    if (fs.activeFolder != null) fs.fetchFiles(fs.activeFolder!);
  }

  Future<void> _moveSelected(FileService fs) async {
    final targetFolder = await showModalBottomSheet<DriveFolder>(
      context: context,
      builder: (ctx) => _FolderPickerSheet(folders: fs.folders.where((f) => f.id != fs.activeFolder?.id).toList()),
    );
    if (targetFolder == null) return;
    for (final file in _selectedFiles) await fs.forwardMessage(file, targetFolder);
    _exitMultiSelect();
    if (fs.activeFolder != null) fs.fetchFiles(fs.activeFolder!);
  }

  Future<void> _createZipSelected(FileService fs) async {
    // Download all selected, zip them, upload back
    for (final file in _selectedFiles) {
      if (!file.isDownloaded) await fs.downloadFile(file);
    }
    // Use archive package to create zip
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
      // Use dart:io Process to call system zip, or use archive package
      // For now create a simple zip using archive package
      final archive = Archive();
      for (final file in files) {
        if (file.localPath != null) {
          final bytes = File(file.localPath!).readAsBytesSync();
          final archiveFile = ArchiveFile(file.fileName, bytes.length, bytes);
          archive.addFile(archiveFile);
        }
      }
      final encoded = ZipEncoder().encode(archive);
      if (encoded == null) return null;
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
        builder: (_) => _DownloadProgressSheet(fs: fs, file: file),
      );
      if (path == null || !mounted) return;
      file.localPath = path;
    }
    if (file.localPath == null) return;

    try {
      final bytes = await File(file.localPath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final extractDir = Directory.systemTemp.createTempSync('extract_${file.messageId}_');
      final extracted = <_ZipEntry>[];

      for (final entry in archive) {
        if (entry.isFile) {
          final outPath = '${extractDir.path}/${entry.name}';
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          await outFile.writeAsBytes(entry.content as List<int>);
          extracted.add(_ZipEntry(
            name: entry.name,
            path: outPath,
            size: entry.size,
            isFile: true,
          ));
        }
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        builder: (_) => _ZipContentSheet(
          zipFileName: file.fileName,
          entries: extracted,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Extract failed: $e')));
      }
    }
  }

  // ─── Format Helpers ───────────────────────────────────────────

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

  String _formatDuration(int secs) {
    final min = (secs ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<FileService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _multiSelectMode
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: _exitMultiSelect),
              title: Text('${_selectedFiles.length} selected'),
              actions: [
                IconButton(icon: const Icon(Icons.download), tooltip: 'Download', onPressed: _selectedFiles.isEmpty ? null : () => _downloadSelected(fs)),
                IconButton(icon: const Icon(Icons.drive_file_move), tooltip: 'Move', onPressed: _selectedFiles.isEmpty ? null : () => _moveSelected(fs)),
                IconButton(icon: const Icon(Icons.folder_zip), tooltip: 'Create Zip', onPressed: _selectedFiles.length < 2 ? null : () => _createZipSelected(fs)),
                IconButton(icon: Icon(Icons.delete, color: theme.colorScheme.error), tooltip: 'Move to Trash', onPressed: _selectedFiles.isEmpty ? null : () => _moveToTrashSelected(fs)),
              ],
            )
          : AppBar(
              title: Text(fs.activeFolder?.title ?? 'TeleDrive'),
              actions: [
                PopupMenuButton<_SortMode>(
                  icon: const Icon(Icons.sort), tooltip: 'Sort',
                  onSelected: (v) => setState(() => _sortMode = v),
                  initialValue: _sortMode,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: _SortMode.newest, child: Text('Newest', style: _sortMode == _SortMode.newest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
                    PopupMenuItem(value: _SortMode.oldest, child: Text('Oldest', style: _sortMode == _SortMode.oldest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
                    PopupMenuItem(value: _SortMode.largest, child: Text('Largest', style: _sortMode == _SortMode.largest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
                    PopupMenuItem(value: _SortMode.smallest, child: Text('Smallest', style: _sortMode == _SortMode.smallest ? const TextStyle(fontWeight: FontWeight.bold) : null)),
                    PopupMenuItem(value: _SortMode.nameAZ, child: Text('Name A-Z', style: _sortMode == _SortMode.nameAZ ? const TextStyle(fontWeight: FontWeight.bold) : null)),
                  ],
                ),
              ],
              bottom: fs.loading && fs.files.isEmpty ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search files...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                                : null,
                            filled: true, isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
            ),
      drawer: _buildDrawer(context, fs, theme),
      body: _buildBody(context, fs, theme),
      floatingActionButton: _multiSelectMode ? null
          : FloatingActionButton(onPressed: fs.activeFolder != null ? () => _pickAndUpload(fs) : null, child: const Icon(Icons.upload)),
    );
  }

  // ─── Drawer ───────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context, FileService fs, ThemeData theme) {
    final themeService = context.read<ThemeService>();
    final telegram = context.read<TelegramService>();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Icon(Icons.cloud_outlined, size: 48, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(height: 8),
              Text('TeleDrive', style: theme.textTheme.titleLarge),
            ]),
          ),
          // ── Home ──
          _drawerSectionHeader('Home', theme),
          ...fs.folders.map((folder) {
            final isSaved = folder.type == 'saved';
            return ListTile(
              leading: Icon(isSaved ? Icons.save : Icons.folder),
              title: Text(folder.title),
              selected: fs.activeFolder?.id == folder.id,
              onTap: () { fs.fetchFiles(folder); Navigator.pop(context); },
              onLongPress: isSaved ? null : () => _showFolderOptions(context, fs, folder),
            );
          }),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New Folder'),
            onTap: () { Navigator.pop(context); _showCreateFolderDialog(context, fs); },
          ),
          const Divider(),
          // ── Recents ──
          _drawerSectionHeader('Recents', theme),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Recent Files'),
            onTap: () { Navigator.pop(context); _tabController.animateTo(6); },
          ),
          const Divider(),
          // ── Favorites ──
          _drawerSectionHeader('Favorites', theme),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('Favorite Files'),
            onTap: () { Navigator.pop(context); _tabController.animateTo(5); },
          ),
          const Divider(),
          // ── Backups ──
          _drawerSectionHeader('Backups', theme),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Auto Backup'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSetupPage())); },
          ),
          const Divider(),
          // ── Trash ──
          _drawerSectionHeader('Trash', theme),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text('Trash', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashPage())); },
          ),
          const Divider(),
          // ── Settings ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const Icon(Icons.palette_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness)),
                  ],
                  selected: {themeService.themeMode},
                  onSelectionChanged: (v) => themeService.setThemeMode(v.first),
                  style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ),
            ]),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () { Navigator.pop(context); telegram.logout(); },
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
    );
  }

  // ─── Folder Dialogs ───────────────────────────────────────────

  void _showCreateFolderDialog(BuildContext context, FileService fs) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('New Folder'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Channel name', border: OutlineInputBorder()), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { fs.createFolder(ctrl.text.trim()); Navigator.pop(ctx); } }, child: const Text('Create')),
      ],
    ));
  }

  void _showFolderOptions(BuildContext context, FileService fs, DriveFolder folder) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.edit), title: const Text('Rename'), onTap: () { Navigator.pop(ctx); _showRenameDialog(context, fs, folder); }),
      ListTile(leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)), onTap: () { Navigator.pop(ctx); _showDeleteConfirm(context, fs, folder); }),
    ])));
  }

  void _showRenameDialog(BuildContext context, FileService fs, DriveFolder folder) {
    final ctrl = TextEditingController(text: folder.title);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rename Folder'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'New name', border: OutlineInputBorder()), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (ctrl.text.trim().isNotEmpty) { fs.renameFolder(folder, ctrl.text.trim()); Navigator.pop(ctx); } }, child: const Text('Rename')),
      ],
    ));
  }

  void _showDeleteConfirm(BuildContext context, FileService fs, DriveFolder folder) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Folder'),
      content: Text('Are you sure you want to delete "${folder.title}"? This will permanently delete the channel and all its messages.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
          onPressed: () { fs.deleteFolder(folder); Navigator.pop(ctx); }, child: const Text('Delete')),
      ],
    ));
  }

  // ─── Body ─────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, FileService fs, ThemeData theme) {
    if (fs.error != null && fs.files.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 16), Text(fs.error!), const SizedBox(height: 16),
        FilledButton.tonal(onPressed: () { if (fs.activeFolder != null) fs.fetchFiles(fs.activeFolder!); }, child: const Text('Retry')),
      ]));
    }
    if (fs.loading && fs.files.isEmpty) return const ShimmerList();
    if (!fs.loading && fs.files.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_open, size: 64, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16), Text(fs.activeFolder != null ? 'Empty folder' : 'Select a folder', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8), Text('Tap + to upload files', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]));
    }

    return SafeArea(
      child: Column(children: [
        TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.fill,
          isScrollable: true,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: [
            const Tab(text: 'All'),
            const Tab(text: 'Images'),
            const Tab(text: 'Videos'),
            const Tab(text: 'Audio'),
            const Tab(text: 'Docs'),
            const Tab(icon: Icon(Icons.star, size: 18), text: 'Fav'),
            const Tab(icon: Icon(Icons.history, size: 18), text: 'Recent'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllTab(context, fs, _applySort(_applySearch(fs.files)), theme),
              _buildImagesTab(context, fs, _applySort(_applySearch(fs.images))),
              _buildListTab(context, fs, _applySort(_applySearch(fs.videos)), icon: Icons.videocam, color: Colors.blue),
              _buildListTab(context, fs, _applySort(_applySearch(fs.audioFiles)), icon: Icons.audiotrack, color: Colors.orange),
              _buildListTab(context, fs, _applySort(_applySearch(fs.documents)), icon: Icons.insert_drive_file, color: Colors.grey),
              _buildFavoritesTab(context, theme),
              _buildRecentsTab(context, theme),
            ],
          ),
        ),
      ]),
    );
  }

  // ─── Stats Card ───────────────────────────────────────────────

  Widget _buildStatsCard(ThemeData theme) {
    if (_stats == null) return const SizedBox.shrink();
    final totalFiles = _stats!['totalFiles'] ?? 0;
    final totalSize = _stats!['totalSize'] ?? 0;
    final cats = _stats!['categories'] as Map<String, dynamic>? ?? {};
    final sizes = _stats!['sizes'] as Map<String, dynamic>? ?? {};

    final items = ['images', 'videos', 'audio', 'documents'];
    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.grey];
    final icons = [Icons.image, Icons.videocam, Icons.audiotrack, Icons.insert_drive_file];
    final totalCatCount = items.fold<int>(0, (s, k) => s + ((cats[k] as num?)?.toInt() ?? 0));

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${_formatNumber(totalFiles)} files',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Text(_formatSize(totalSize),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(children: items.asMap().entries.map((e) {
                final count = (cats[e.value] as num?)?.toInt() ?? 0;
                final flex = totalCatCount > 0 ? count : 0;
                return flex > 0
                    ? Expanded(flex: flex, child: Container(color: colors[e.key]))
                    : const SizedBox.shrink();
              }).toList()),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, children: items.asMap().entries.map((e) {
            final count = (cats[e.value] as num?)?.toInt() ?? 0;
            final sz = (sizes[e.value] as num?)?.toInt() ?? 0;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icons[e.key], size: 14, color: colors[e.key]),
              const SizedBox(width: 4),
              Text('${_formatNumber(count)} · ${_formatSize(sz)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ]);
          }).toList()),
        ]),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  // ─── Tab Builders ─────────────────────────────────────────────

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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildStatsCard(theme),
          ...sections.entries.expand((entry) => [
            _SectionHeader(title: entry.key, count: entry.value.length),
            ...entry.value.map((f) => _buildFileRow(context, fs, f)),
          ]),
          if (sections.isEmpty) _emptyState(context),
        ],
      ),
    );
  }

  Widget _buildImagesTab(BuildContext context, FileService fs, List<DriveFile> files) {
    if (files.isEmpty) return _emptyState(context);
    return RefreshIndicator(
      onRefresh: () async { if (fs.activeFolder != null) await fs.fetchFiles(fs.activeFolder!); },
      child: GridView.builder(
        padding: EdgeInsets.zero, physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 0, crossAxisSpacing: 0, childAspectRatio: 1),
        itemCount: files.length,
        itemBuilder: (context, index) => _buildImageGridItem(context, fs, files[index], files, index),
      ),
    );
  }

  Widget _buildListTab(BuildContext context, FileService fs, List<DriveFile> files, {required IconData icon, required Color color}) {
    if (files.isEmpty) return _emptyState(context);
    return RefreshIndicator(
      onRefresh: () async { if (fs.activeFolder != null) await fs.fetchFiles(fs.activeFolder!); },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4), physics: const AlwaysScrollableScrollPhysics(),
        itemCount: files.length,
        itemBuilder: (context, index) => _buildListItem(context, fs, files[index], icon: icon, color: color),
      ),
    );
  }

  Widget _buildFavoritesTab(BuildContext context, ThemeData theme) {
    final fav = context.watch<FavoritesService>();
    if (fav.loading) return const Center(child: CircularProgressIndicator());
    if (fav.favorites.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star_outline, size: 64, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16), Text('No favorites yet', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8), Text('Tap the star icon on any file to favorite it', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]));
    }
    final images = fav.favorites.where((f) => f.isImage).toList();
    final videos = fav.favorites.where((f) => f.isVideo).toList();
    final audio = fav.favorites.where((f) => f.isAudio).toList();
    final docs = fav.favorites.where((f) => !f.isImage && !f.isVideo && !f.isAudio).toList();
    final sections = <String, List<DriveFile>>{};
    if (images.isNotEmpty) sections['Images'] = images;
    if (videos.isNotEmpty) sections['Videos'] = videos;
    if (audio.isNotEmpty) sections['Audio'] = audio;
    if (docs.isNotEmpty) sections['Documents'] = docs;

    return ListView(children: sections.entries.expand((entry) => [
      _SectionHeader(title: entry.key, count: entry.value.length),
      ...entry.value.map((f) => _buildFavItem(context, f)),
    ]).toList());
  }

  Widget _buildFavItem(BuildContext context, DriveFile file) {
    final theme = Theme.of(context);
    IconData icon; Color color;
    if (file.isImage) { icon = Icons.image; color = Colors.green; }
    else if (file.isVideo) { icon = Icons.videocam; color = Colors.blue; }
    else if (file.isAudio) { icon = Icons.audiotrack; color = Colors.orange; }
    else { icon = Icons.insert_drive_file; color = Colors.grey; }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 22, color: color),
        ),
        title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text('${_formatSize(file.size)} · ${_formatDate(file.date)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        trailing: IconButton(
          icon: Icon(Icons.star, color: Colors.amber),
          onPressed: () async {
            final fav = context.read<FavoritesService>();
            final api = context.read<ApiService>();
            await api.removeFavorite(file.messageId);
            await fav.fetchFavorites();
          },
        ),
      ),
    );
  }

  Widget _buildRecentsTab(BuildContext context, ThemeData theme) {
    if (!_recentsLoaded) return const Center(child: CircularProgressIndicator());
    if (_recents.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history, size: 64, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16), Text('No recent files', style: theme.textTheme.titleMedium),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _recents.length,
      itemBuilder: (context, index) {
        final file = _recents[index];
        IconData icon; Color color;
        if (file.isImage) { icon = Icons.image; color = Colors.green; }
        else if (file.isVideo) { icon = Icons.videocam; color = Colors.blue; }
        else if (file.isAudio) { icon = Icons.audiotrack; color = Colors.orange; }
        else { icon = Icons.insert_drive_file; color = Colors.grey; }
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            leading: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 22, color: color),
            ),
            title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${_formatSize(file.size)} · ${_formatDate(file.date)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        );
      },
    );
  }

  // ─── Item Builders ────────────────────────────────────────────

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

    return GestureDetector(
      onTap: () {
        if (_multiSelectMode) _toggleSelect(file);
        else _downloadAndPreview(context, fs, file, imageList: allImages, imageIndex: index);
      },
      onLongPress: () => _enterMultiSelect(file),
      child: Stack(fit: StackFit.expand, children: [
        Hero(tag: 'image_${file.docId}', child: child),
        if (selected)
          Container(color: Colors.blue.withOpacity(0.3), child: Center(child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.check, size: 16, color: Colors.white)))),
      ]),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      child: Center(child: Icon(Icons.image, size: 28, color: isDark ? Colors.white24 : Colors.black26)));
  }

  Widget _buildFileRow(BuildContext context, FileService fs, DriveFile file) {
    IconData icon; Color color;
    switch (file.categoryIcon) {
      case 'image': icon = Icons.image; color = Colors.green; break;
      case 'video': icon = Icons.videocam; color = Colors.blue; break;
      case 'audio': icon = Icons.audiotrack; color = Colors.orange; break;
      default: icon = Icons.insert_drive_file; color = Colors.grey;
    }
    return _buildListItem(context, fs, file, icon: icon, color: color);
  }

  Widget _buildListItem(BuildContext context, FileService fs, DriveFile file, {required IconData icon, required Color color}) {
    final theme = Theme.of(context);
    final selected = _selectedFiles.contains(file);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () { if (_multiSelectMode) _toggleSelect(file); else _downloadAndPreview(context, fs, file); },
        onLongPress: () => _enterMultiSelect(file),
        child: Container(
          color: selected ? Colors.blue.withOpacity(0.08) : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              if (_multiSelectMode)
                Padding(padding: const EdgeInsets.only(right: 8), child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? Colors.blue : theme.colorScheme.onSurfaceVariant, size: 22)),
              Container(width: 42, height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 22, color: color)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(file.fileName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(_formatSize(file.size), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Text(' · ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Text(_formatDate(file.date), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (file.duration > 0) ...[
                    Text(' · ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    Text(_formatDuration(file.duration), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ]),
              ])),
              if (!_multiSelectMode)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (file.isZip)
                    IconButton(
                      icon: const Icon(Icons.unarchive, size: 20),
                      color: theme.colorScheme.onSurfaceVariant,
                      tooltip: 'Extract',
                      onPressed: () => _extractZip(context, fs, file),
                    ),
                  IconButton(
                    icon: Icon(Icons.star_border, size: 20),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () async {
                      final fav = context.read<FavoritesService>();
                      final chatId = fs.activeFolder?.chatId?.toString() ?? '';
                      await fav.toggleFavorite(file, chatId, '');
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${fav.favorites.any((f) => f.messageId == file.messageId) ? "Added to" : "Removed from"} favorites'), duration: const Duration(seconds: 1)),
                      );
                    },
                  ),
                ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(height: 16),
      Text(_searchQuery.isNotEmpty ? 'No matching files' : 'No files here', style: Theme.of(context).textTheme.titleMedium),
    ]));
  }
}

// ─── Section Header ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title; final int count;
  const _SectionHeader({required this.title, required this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 6),
        Text('$count', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

// ─── Folder Picker Sheet ───────────────────────────────────────

class _FolderPickerSheet extends StatelessWidget {
  final List<DriveFolder> folders;
  const _FolderPickerSheet({required this.folders});
  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Move to folder', style: Theme.of(context).textTheme.titleMedium)),
      if (folders.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No other folders available'))
      else ...folders.map((f) => ListTile(leading: Icon(f.type == 'saved' ? Icons.save : Icons.folder), title: Text(f.title), onTap: () => Navigator.pop(context, f))),
      const SizedBox(height: 8),
    ]));
  }
}

// ─── Multi-File Upload Sheet ───────────────────────────────────

class _MultiUploadSheet extends StatefulWidget {
  final FileService fs; final DriveFolder folder; final List<PlatformFile> files;
  const _MultiUploadSheet({required this.fs, required this.folder, required this.files});
  @override
  State<_MultiUploadSheet> createState() => _MultiUploadSheetState();
}

class _MultiUploadSheetState extends State<_MultiUploadSheet> {
  final Map<int, double> _progress = {};
  int _completed = 0; int _failed = 0; bool _done = false;

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
    final theme = Theme.of(context);
    final total = widget.files.length;
    final pct = total > 0 ? (_completed + _failed) / total : 0.0;
    return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [ Icon(_done ? Icons.check_circle : Icons.cloud_upload, color: _done ? Colors.green : theme.colorScheme.primary), const SizedBox(width: 12),
        Text(_done ? 'Upload complete' : 'Uploading ${widget.files.length} files...', style: theme.textTheme.titleMedium) ]),
      const SizedBox(height: 12),
      LinearProgressIndicator(value: _done ? 1.0 : pct),
      const SizedBox(height: 8),
      Text('$_completed done · $_failed failed · ${total - _completed - _failed} remaining', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      SizedBox(height: 160, child: ListView.separated(itemCount: widget.files.length, separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final file = widget.files[index]; final progress = _progress[index];
          return ListTile(dense: true, leading: Icon(progress == 1.0 ? Icons.check_circle : progress == -1 ? Icons.error : Icons.hourglass_empty, size: 18,
            color: progress == 1.0 ? Colors.green : progress == -1 ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
            title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            trailing: progress != null && progress >= 0 ? SizedBox(width: 60, child: LinearProgressIndicator(value: progress, minHeight: 4)) : progress == -1 ? const Icon(Icons.error, size: 16) : null);
        },
      )),
    ]));
  }
}

// ─── Upload Progress Sheet ─────────────────────────────────────

class _UploadProgressSheet extends StatefulWidget {
  final FileService fs; final DriveFolder folder; final String path;
  const _UploadProgressSheet({required this.fs, required this.folder, required this.path});
  @override
  State<_UploadProgressSheet> createState() => _UploadProgressSheetState();
}

class _UploadProgressSheetState extends State<_UploadProgressSheet> {
  bool _completed = false; String? _error;
  @override
  void initState() { super.initState(); _startUpload(); }
  Future<void> _startUpload() async {
    try { await widget.fs.uploadFile(widget.folder, widget.path);
      if (mounted) { setState(() => _completed = true); await Future.delayed(const Duration(seconds: 1)); if (mounted) Navigator.pop(context); }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }
  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    final fileName = widget.path.split('/').last;
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(_completed ? Icons.check_circle : _error != null ? Icons.error : Icons.cloud_upload, size: 48,
          color: _completed ? Colors.green : _error != null ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(_completed ? 'Upload complete' : _error != null ? 'Upload failed' : 'Uploading...', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8), Text(fileName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 16),
        if (_error == null) LinearProgressIndicator(value: _completed ? 1.0 : telegram.uploadProgress),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)],
        const SizedBox(height: 8),
        Text(_completed ? '100%' : _error != null ? '' : '${(telegram.uploadProgress * 100).toInt()}%', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ─── Download Progress Sheet ───────────────────────────────────

class _DownloadProgressSheet extends StatefulWidget {
  final FileService fs; final DriveFile file;
  const _DownloadProgressSheet({required this.fs, required this.file});
  @override
  State<_DownloadProgressSheet> createState() => _DownloadProgressSheetState();
}

class _DownloadProgressSheetState extends State<_DownloadProgressSheet> {
  bool _completed = false; String? _error; String? _resultPath;
  @override
  void initState() { super.initState(); _startDownload(); }
  Future<void> _startDownload() async {
    try { final path = await widget.fs.downloadFile(widget.file);
      if (mounted) { if (path != null) { _resultPath = path; setState(() => _completed = true); await Future.delayed(const Duration(milliseconds: 500)); if (mounted) Navigator.pop(context, _resultPath); } else setState(() => _error = 'Download failed'); }
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }
  @override
  Widget build(BuildContext context) {
    final telegram = context.watch<TelegramService>();
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(_completed ? Icons.check_circle : _error != null ? Icons.error : Icons.cloud_download, size: 48,
          color: _completed ? Colors.green : _error != null ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(_completed ? 'Download complete' : _error != null ? 'Download failed' : 'Downloading...', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8), Text(widget.file.fileName, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 16),
        if (_error == null) LinearProgressIndicator(value: _completed ? 1.0 : telegram.downloadProgress),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)],
        const SizedBox(height: 8),
        Text(_completed ? '100%' : _error != null ? '' : '${(telegram.downloadProgress * 100).toInt()}%', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ─── Zip Extract ────────────────────────────────────────────────

class _ZipEntry {
  final String name;
  final String path;
  final int size;
  final bool isFile;
  const _ZipEntry({
    required this.name,
    required this.path,
    required this.size,
    required this.isFile,
  });
}

class _ZipContentSheet extends StatelessWidget {
  final String zipFileName;
  final List<_ZipEntry> entries;
  const _ZipContentSheet({required this.zipFileName, required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(children: [
          HandleBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(Icons.unarchive, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.basename(zipFileName),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('${entries.length} files', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text('Empty archive', style: theme.textTheme.bodyMedium))
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final ext = p.extension(entry.name).toLowerCase();
                      IconData icon;
                      Color color;
                      if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
                        icon = Icons.image; color = Colors.green;
                      } else if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) {
                        icon = Icons.videocam; color = Colors.blue;
                      } else if (['.mp3', '.wav', '.aac', '.flac'].contains(ext)) {
                        icon = Icons.audiotrack; color = Colors.orange;
                      } else if (['.pdf'].contains(ext)) {
                        icon = Icons.picture_as_pdf; color = Colors.red;
                      } else if (['.zip', '.tar', '.gz', '.rar'].contains(ext)) {
                        icon = Icons.folder_zip; color = Colors.grey;
                      } else {
                        icon = Icons.insert_drive_file; color = Colors.grey;
                      }

                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon, size: 20, color: color),
                        ),
                        title: Text(p.basename(entry.name), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        subtitle: Text(p.dirname(entry.name).isEmpty ? '' : p.dirname(entry.name),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        trailing: Text(formatFileSize(entry.size),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
    );
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class HandleBar extends StatelessWidget {
  const HandleBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(child: Container(
      width: 32, height: 4,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
    ));
  }
}
