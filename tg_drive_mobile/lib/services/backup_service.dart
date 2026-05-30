import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';
import 'backup_worker.dart';

class BackupConfig {
  final List<String> selectedFolderIds;
  final bool autoBackup;
  final bool useOriginal;
  final Map<String, int> lastBackupTimestamps;
  final Map<String, int> fileCounts;
  final Map<String, int> storageUsed;
  final String? destFolderId;
  final String? destFolderName;

  BackupConfig({
    this.selectedFolderIds = const [],
    this.autoBackup = false,
    this.useOriginal = true,
    this.lastBackupTimestamps = const {},
    this.fileCounts = const {},
    this.storageUsed = const {},
    this.destFolderId,
    this.destFolderName,
  });
}

class BackupFolderInfo {
  final String id;
  final String name;
  final int fileCount;
  final bool selected;
  final bool backedUp;
  final int lastBackupTime;
  final int storageUsed;

  BackupFolderInfo({
    required this.id,
    required this.name,
    this.fileCount = 0,
    this.selected = false,
    this.backedUp = false,
    this.lastBackupTime = 0,
    this.storageUsed = 0,
  });
}

class BackupProgress {
  final String folderName;
  final int completedFiles;
  final int totalFiles;
  final String currentFile;
  final bool done;
  final String? error;
  final int totalBytes;
  final int uploadedBytes;

  BackupProgress({
    this.folderName = '',
    this.completedFiles = 0,
    this.totalFiles = 0,
    this.currentFile = '',
    this.done = false,
    this.error,
    this.totalBytes = 0,
    this.uploadedBytes = 0,
  });

  double get progress =>
      totalFiles > 0 ? completedFiles / totalFiles : 0.0;
}

class BackupService extends ChangeNotifier {
  final ApiService _api;
  BackupConfig _config = BackupConfig();
  List<BackupFolderInfo> _folders = [];
  BackupProgress _progress = BackupProgress();
  bool _scanning = false;
  bool _backingUp = false;

  BackupService(this._api);

  BackupConfig get config => _config;
  List<BackupFolderInfo> get folders => _folders;
  BackupProgress get progress => _progress;
  bool get scanning => _scanning;
  bool get backingUp => _backingUp;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _config = BackupConfig(
      selectedFolderIds:
          (prefs.getStringList('backup_folders') ?? []),
      autoBackup: prefs.getBool('backup_auto') ?? false,
      useOriginal: prefs.getBool('backup_original') ?? true,
      lastBackupTimestamps: _decodeMap(prefs.getString('backup_timestamps')),
      fileCounts: _decodeMap(prefs.getString('backup_file_counts')),
      storageUsed: _decodeMap(prefs.getString('backup_storage')),
      destFolderId: prefs.getString('backup_dest_folder_id'),
      destFolderName: prefs.getString('backup_dest_folder_name'),
    );
    notifyListeners();
  }

  Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('backup_folders', _config.selectedFolderIds);
    await prefs.setBool('backup_auto', _config.autoBackup);
    await prefs.setBool('backup_original', _config.useOriginal);
    await prefs.setString(
        'backup_timestamps', _encodeMap(_config.lastBackupTimestamps));
    await prefs.setString(
        'backup_file_counts', _encodeMap(_config.fileCounts));
    await prefs.setString(
        'backup_storage', _encodeMap(_config.storageUsed));
    if (_config.destFolderId != null) {
      await prefs.setString('backup_dest_folder_id', _config.destFolderId!);
    } else {
      await prefs.remove('backup_dest_folder_id');
    }
    if (_config.destFolderName != null) {
      await prefs.setString('backup_dest_folder_name', _config.destFolderName!);
    } else {
      await prefs.remove('backup_dest_folder_name');
    }
  }

  Map<String, int> _decodeMap(String? json) {
    if (json == null || json.isEmpty) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  String _encodeMap(Map<String, int> map) => jsonEncode(map);

  Future<void> scanDeviceFolders() async {
    _scanning = true;
    notifyListeners();

    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: false,
      );

      final counted = <BackupFolderInfo>[];
      for (final a in albums) {
        final count = await a.assetCountAsync;
        if (count == 0) continue;
        final id = a.id;
        final isSelected = _config.selectedFolderIds.contains(id);
        final lastTime = _config.lastBackupTimestamps[id] ?? 0;
        counted.add(BackupFolderInfo(
          id: id,
          name: a.name,
          fileCount: count,
          selected: isSelected,
          backedUp: lastTime > 0,
          lastBackupTime: lastTime,
          storageUsed: _config.storageUsed[id] ?? 0,
        ));
      }
      _folders = counted;
    } catch (e) {
      debugPrint('Failed to scan folders: $e');
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  void toggleFolder(String id, bool selected) {
    final ids = List<String>.from(_config.selectedFolderIds);
    if (selected) {
      if (!ids.contains(id)) ids.add(id);
    } else {
      ids.remove(id);
    }
    _config = BackupConfig(
      selectedFolderIds: ids,
      autoBackup: _config.autoBackup,
      useOriginal: _config.useOriginal,
      lastBackupTimestamps: _config.lastBackupTimestamps,
      fileCounts: _config.fileCounts,
      storageUsed: _config.storageUsed,
      destFolderId: _config.destFolderId,
      destFolderName: _config.destFolderName,
    );
    saveConfig();
    notifyListeners();
  }

  void setAutoBackup(bool value) {
    _config = BackupConfig(
      selectedFolderIds: _config.selectedFolderIds,
      autoBackup: value,
      useOriginal: _config.useOriginal,
      lastBackupTimestamps: _config.lastBackupTimestamps,
      fileCounts: _config.fileCounts,
      storageUsed: _config.storageUsed,
      destFolderId: _config.destFolderId,
      destFolderName: _config.destFolderName,
    );
    saveConfig();
    if (value) {
      _registerPeriodicTask();
    } else {
      _cancelPeriodicTask();
    }
    notifyListeners();
  }

  Future<void> _registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      backupTaskName,
      backupTaskName,
      tag: backupTaskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  Future<void> _cancelPeriodicTask() async {
    await Workmanager().cancelByTag(backupTaskName);
  }

  Future<void> saveServerConfig({
    required String apiUrl,
    String? session,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backup_api_url', apiUrl);
      if (session != null) {
        await prefs.setString('backup_server_session', session);
      }
    } catch (e) {
      debugPrint('Failed to save server config: $e');
    }
  }

  void setDestFolder(String? id, String? name) {
    _config = BackupConfig(
      selectedFolderIds: _config.selectedFolderIds,
      autoBackup: _config.autoBackup,
      useOriginal: _config.useOriginal,
      lastBackupTimestamps: _config.lastBackupTimestamps,
      fileCounts: _config.fileCounts,
      storageUsed: _config.storageUsed,
      destFolderId: id,
      destFolderName: name,
    );
    saveConfig();
    notifyListeners();
  }

  void setQuality(bool original) {
    _config = BackupConfig(
      selectedFolderIds: _config.selectedFolderIds,
      autoBackup: _config.autoBackup,
      useOriginal: original,
      lastBackupTimestamps: _config.lastBackupTimestamps,
      fileCounts: _config.fileCounts,
      storageUsed: _config.storageUsed,
      destFolderId: _config.destFolderId,
      destFolderName: _config.destFolderName,
    );
    saveConfig();
    notifyListeners();
  }

  Future<void> runBackup(List<String> folderIds) async {
    if (_backingUp) return;
    _backingUp = true;
    notifyListeners();

    try {
      for (final folderId in folderIds) {
        final folder = _folders.firstWhere(
          (f) => f.id == folderId,
          orElse: () => BackupFolderInfo(id: folderId, name: folderId),
        );

        final allAlbums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
        );
        final target = allAlbums.cast<AssetPathEntity?>().firstWhere(
          (a) => a?.id == folderId,
          orElse: () => null,
        );
        if (target == null) continue;

        final assets = await target.getAssetListPaged(
          page: 0,
          size: 200,
        );

        final lastTime = _config.lastBackupTimestamps[folderId] ?? 0;
        final newAssets = assets.where((a) =>
            a.createDateTime.millisecondsSinceEpoch ~/ 1000 > lastTime).toList();

        if (newAssets.isEmpty) {
          _progress = BackupProgress(
            folderName: folder.name,
            completedFiles: 0,
            totalFiles: 0,
            done: true,
          );
          notifyListeners();
          continue;
        }

        final batchFiles = <Map<String, String>>[];
        int totalBytes = 0;

        for (int i = 0; i < newAssets.length; i++) {
          final asset = newAssets[i];
          _progress = BackupProgress(
            folderName: folder.name,
            completedFiles: i,
            totalFiles: newAssets.length,
            currentFile: 'Preparing file ${i + 1}/${newAssets.length}...',
            totalBytes: totalBytes,
            uploadedBytes: 0,
          );
          notifyListeners();

          final file = await asset.file;
          if (file == null) continue;

          final bytes = await file.readAsBytes();
          totalBytes += bytes.length;
          batchFiles.add({
            'fileName': asset.title ?? 'unknown',
            'data': base64Encode(bytes),
          });
        }

        if (batchFiles.isEmpty) continue;

        _progress = BackupProgress(
          folderName: folder.name,
          completedFiles: 0,
          totalFiles: batchFiles.length,
          currentFile: 'Uploading ${batchFiles.length} files...',
          totalBytes: totalBytes,
          uploadedBytes: 0,
        );
        notifyListeners();

        await _api.backupUploadBatch(folder.name, batchFiles);

        final timestamps =
            Map<String, int>.from(_config.lastBackupTimestamps);
        timestamps[folderId] =
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final counts = Map<String, int>.from(_config.fileCounts);
        counts[folderId] = (counts[folderId] ?? 0) + batchFiles.length;
        final storage = Map<String, int>.from(_config.storageUsed);
        storage[folderId] = (storage[folderId] ?? 0) + totalBytes;

        _config = BackupConfig(
          selectedFolderIds: _config.selectedFolderIds,
          autoBackup: _config.autoBackup,
          useOriginal: _config.useOriginal,
          lastBackupTimestamps: timestamps,
          fileCounts: counts,
          storageUsed: storage,
          destFolderId: _config.destFolderId,
          destFolderName: _config.destFolderName,
        );
        await saveConfig();

        _progress = BackupProgress(
          folderName: folder.name,
          completedFiles: batchFiles.length,
          totalFiles: batchFiles.length,
          done: true,
        );
        notifyListeners();
      }
    } catch (e) {
      _progress = BackupProgress(
        folderName: '',
        done: true,
        error: e.toString(),
      );
    } finally {
      _backingUp = false;
      notifyListeners();
    }
  }

  void removeFolder(String folderId) {
    final ids = List<String>.from(_config.selectedFolderIds);
    ids.remove(folderId);
    final timestamps =
        Map<String, int>.from(_config.lastBackupTimestamps);
    timestamps.remove(folderId);
    final counts = Map<String, int>.from(_config.fileCounts);
    counts.remove(folderId);
    final storage = Map<String, int>.from(_config.storageUsed);
    storage.remove(folderId);

    _config = BackupConfig(
      selectedFolderIds: ids,
      autoBackup: _config.autoBackup,
      useOriginal: _config.useOriginal,
      lastBackupTimestamps: timestamps,
      fileCounts: counts,
      storageUsed: storage,
      destFolderId: _config.destFolderId,
      destFolderName: _config.destFolderName,
    );
    saveConfig();
    _folders = _folders.map((f) {
      if (f.id == folderId) {
        return BackupFolderInfo(
          id: f.id,
          name: f.name,
          fileCount: f.fileCount,
          selected: false,
          backedUp: false,
          lastBackupTime: 0,
          storageUsed: 0,
        );
      }
      return f;
    }).toList();
    notifyListeners();
  }
}
