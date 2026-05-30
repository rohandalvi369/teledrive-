import 'package:flutter/foundation.dart';
import '../models/drive_file.dart';
import 'api_service.dart';

class FavoritesService extends ChangeNotifier {
  final ApiService _api;
  List<DriveFile> _favorites = [];
  bool _loading = false;

  FavoritesService(this._api);

  List<DriveFile> get favorites => _favorites;
  bool get loading => _loading;

  Future<void> fetchFavorites() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getFavorites();
      _favorites = data.map((json) {
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
      debugPrint('Failed to fetch favorites: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> isFavorite(int messageId) =>
      Future.value(_favorites.any((f) => f.messageId == messageId));

  Future<void> toggleFavorite(
    DriveFile file,
    String sourceChatId,
    String sourceAccessHash,
  ) async {
    final exists = _favorites.any((f) => f.messageId == file.messageId);
    if (exists) {
      await _api.removeFavorite(file.messageId);
    } else {
      await _api.addFavorite(file.messageId, sourceChatId, sourceAccessHash);
    }
    await fetchFavorites();
  }
}
