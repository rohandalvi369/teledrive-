import 'package:flutter/foundation.dart';
import '../models/drive_file.dart';
import 'api_service.dart';

class TrashService extends ChangeNotifier {
  final ApiService _api;
  List<DriveFile> _trashFiles = [];
  bool _loading = false;

  TrashService(this._api);

  List<DriveFile> get trashFiles => _trashFiles;
  bool get loading => _loading;

  Future<void> fetchTrash() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getTrash();
      _trashFiles = data.map((json) {
        return DriveFile(
          messageId: (json['messageId'] as num).toInt(),
          docId: json['docId'] as String? ?? '',
          fileName: json['fileName'] as String? ?? 'unknown',
          mimeType: json['mimeType'] as String? ?? '',
          size: (json['size'] as num?)?.toInt() ?? 0,
          date: (json['date'] as num?)?.toInt() ?? 0,
          fileId: (json['fileId'] as num?)?.toInt() ?? 0,
          duration: (json['duration'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch trash: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> moveToTrash(
    List<DriveFile> files,
    String sourceChatId,
    String sourceAccessHash,
  ) async {
    final ids = files.map((f) => f.messageId).toList();
    await _api.moveToTrash(ids, sourceChatId, sourceAccessHash);
    await fetchTrash();
  }

  Future<void> restore(List<int> messageIds) async {
    await _api.restoreFromTrash(messageIds);
    await fetchTrash();
  }

  Future<int> purge() async {
    final result = await _api.purgeTrash();
    await fetchTrash();
    return (result['purged'] as num?)?.toInt() ?? 0;
  }
}
