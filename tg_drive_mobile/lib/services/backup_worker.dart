import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';

const String backupTaskName = 'com.teledrive.backup.periodic';

@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != backupTaskName) return true;

    final notif = NotificationService();
    try {
      await notif.init();
      await notif.showProgress(
        current: 0,
        total: 0,
        currentFile: 'Starting auto-backup...',
      );
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();

      final folderIds = prefs.getStringList('backup_folders') ?? [];
      final autoBackup = prefs.getBool('backup_auto') ?? false;

      if (!autoBackup || folderIds.isEmpty) {
        await notif.cancelAll();
        return true;
      }

      final apiBaseUrl =
          prefs.getString('backup_api_url') ?? 'http://localhost:3001';

      final session = prefs.getString('backup_server_session');

      final timestampsJson = prefs.getString('backup_timestamps');
      final lastBackupTimestamps =
          timestampsJson != null && timestampsJson.isNotEmpty
              ? Map<String, int>.from(
                  (jsonDecode(timestampsJson) as Map).map(
                    (k, v) => MapEntry(k as String, (v as num).toInt()),
                  ),
                )
              : <String, int>{};

      final countsJson = prefs.getString('backup_file_counts');
      final fileCounts = countsJson != null && countsJson.isNotEmpty
          ? Map<String, int>.from(
              (jsonDecode(countsJson) as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toInt()),
              ),
            )
          : <String, int>{};

      final storageJson = prefs.getString('backup_storage');
      final storageUsed = storageJson != null && storageJson.isNotEmpty
          ? Map<String, int>.from(
              (jsonDecode(storageJson) as Map).map(
                (k, v) => MapEntry(k as String, (v as num).toInt()),
              ),
            )
          : <String, int>{};

      List<AssetPathEntity> allAlbums;
      try {
        final rawAlbums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          hasAll: false,
        );
        allAlbums = [];
        for (final a in rawAlbums) {
          final count = await a.assetCountAsync;
          if (count > 0) allAlbums.add(a);
        }
      } catch (e) {
        await notif.showError(
          'Could not access device photos in background. '
          'Open TeleDrive to run backup manually.',
        );
        return false;
      }

      final albumMap = {
        for (final a in allAlbums) a.id: a,
      };

      int totalSuccess = 0;
      int totalFoldersProcessed = 0;
      String? lastError;

      for (final folderId in folderIds) {
        final album = albumMap[folderId];
        if (album == null) continue;

        final folderName = album.name;

        final lastTime = lastBackupTimestamps[folderId] ?? 0;
        final assets = await album.getAssetListPaged(page: 0, size: 200);

        final newAssets = assets
            .where((a) =>
                a.createDateTime.millisecondsSinceEpoch ~/ 1000 > lastTime)
            .toList();

        if (newAssets.isEmpty) {
          totalFoldersProcessed++;
          continue;
        }

        const int maxBatch = 5;
        final batch = newAssets.take(maxBatch).toList();
        final batchFiles = <File>[];
        final batchFileNames = <String>[];
        int totalBytes = 0;

        for (int i = 0; i < batch.length; i++) {
          final asset = batch[i];
          await notif.showProgress(
            current: i,
            total: batch.length,
            currentFile: asset.title ?? 'unknown',
            folderName: folderName,
          );

          try {
            final file = await asset.file;
            if (file == null) continue;

            final size = await file.length();
            totalBytes += size;
            batchFiles.add(file);
            batchFileNames.add(asset.title ?? 'unknown');
          } catch (e) {
            debugPrint('BackupWorker: failed to read asset: $e');
          }
        }

        if (batchFiles.isEmpty) continue;

        try {
          final uri = Uri.parse('$apiBaseUrl/backup/upload-stream');
          final req = http.MultipartRequest('POST', uri);
          req.fields['folderName'] = folderName;
          for (int i = 0; i < batchFiles.length; i++) {
            req.files.add(await http.MultipartFile(
              'files',
              batchFiles[i].openRead(),
              await batchFiles[i].length(),
              filename: batchFileNames[i],
            ));
          }

          final streamed = await req.send().timeout(const Duration(minutes: 10));
          final response = await http.Response.fromStream(streamed);

          if (response.statusCode == 200) {
            final updatedTimestamps =
                Map<String, int>.from(lastBackupTimestamps);
            updatedTimestamps[folderId] =
                DateTime.now().millisecondsSinceEpoch ~/ 1000;
            lastBackupTimestamps..clear()..addAll(updatedTimestamps);

            final updatedCounts = Map<String, int>.from(fileCounts);
            updatedCounts[folderId] =
                (updatedCounts[folderId] ?? 0) + batchFiles.length;
            fileCounts..clear()..addAll(updatedCounts);

            final updatedStorage = Map<String, int>.from(storageUsed);
            updatedStorage[folderId] =
                (updatedStorage[folderId] ?? 0) + totalBytes;
            storageUsed..clear()..addAll(updatedStorage);

            totalSuccess += batchFiles.length;
            totalFoldersProcessed++;

            await prefs.setString(
                'backup_timestamps', jsonEncode(lastBackupTimestamps));
            await prefs.setString(
                'backup_file_counts', jsonEncode(fileCounts));
            await prefs.setString(
                'backup_storage', jsonEncode(storageUsed));
          } else {
            lastError = 'Server returned ${response.statusCode}';
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint('BackupWorker: upload failed: $e');
        }
      }

      if (totalSuccess > 0) {
        await notif.showComplete(
          totalFiles: totalSuccess,
          totalFolders: totalFoldersProcessed,
        );
      } else if (lastError != null) {
        await notif.showError(lastError);
      } else {
        await notif.cancelAll();
      }

      return true;
    } catch (e) {
      try {
        await notif.showError('Auto-backup failed: $e');
      } catch (_) {}
      return false;
    }
  });
}
