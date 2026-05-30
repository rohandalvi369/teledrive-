import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final http.Client _client = http.Client();

  ApiService({this.baseUrl = 'http://localhost:3001'});

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final resp = await _client.get(Uri.parse('$baseUrl$path'));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> _delete(
      String path, Map<String, dynamic> body) async {
    final req = http.Request('DELETE', Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    req.body = jsonEncode(body);
    final streamed = await _client.send(req);
    final resp = await http.Response.fromStream(streamed);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  // ─── Auth ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendPhone(String phone) =>
      _post('/auth/phone', {'phoneNumber': phone});

  Future<Map<String, dynamic>> verifyCode(
          String phone, String code, String? phoneCodeHash) =>
      _post('/auth/verify', {
        'phoneNumber': phone,
        'code': code,
        'phoneCodeHash': phoneCodeHash ?? '',
      });

  Future<Map<String, dynamic>> checkPassword(String password) =>
      _post('/auth/password', {'password': password});

  Future<Map<String, dynamic>> getAuthState() => _get('/auth/state');

  Future<void> logout() => _post('/auth/logout', {});

  // ─── Folders ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFolders() async {
    final data = await _get('/folders');
    return List<Map<String, dynamic>>.from(data['folders'] ?? []);
  }

  Future<Map<String, dynamic>> createFolder(
          String title, String? description) =>
      _post('/folders/create', {
        'title': title,
        'description': description ?? 'tg-drive-folder',
      });

  Future<void> renameFolder(String id, String title, String accessHash) =>
      _put('/folders/$id/rename', {'title': title, 'accessHash': accessHash});

  Future<void> deleteFolder(String id, String accessHash) =>
      _delete('/folders/$id', {'accessHash': accessHash});

  // ─── Files ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listFiles(
      String chatId, String accessHash,
      {String? type}) async {
    final data = await _post('/files/list', {
      'chatId': chatId,
      'accessHash': accessHash,
      if (type != null) 'type': type,
    });
    return List<Map<String, dynamic>>.from(data['files'] ?? []);
  }

  Future<Map<String, dynamic>> uploadFiles(
    String chatId,
    String accessHash,
    List<File> files,
  ) async {
    final uri = Uri.parse('$baseUrl/upload');
    final req = http.MultipartRequest('POST', uri);
    req.fields['chatId'] = chatId;
    req.fields['accessHash'] = accessHash;
    for (final file in files) {
      req.files.add(await http.MultipartFile.fromPath('files', file.path));
    }
    final streamed = await _client.send(req);
    final resp = await http.Response.fromStream(streamed);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUploadProgress(String batchId) =>
      _get('/upload/$batchId/progress');

  Future<Map<String, dynamic>> downloadFiles(
      String chatId, String accessHash, List<int> messageIds) async {
    final data = await _post('/files/download', {
      'chatId': chatId,
      'accessHash': accessHash,
      'messageIds': messageIds,
    });
    return data;
  }

  Future<void> deleteFiles(
      String chatId, String accessHash, List<int> messageIds) async {
    await _post('/files/delete', {
      'chatId': chatId,
      'accessHash': accessHash,
      'messageIds': messageIds,
    });
  }

  Future<void> moveFiles(String fromChatId, String fromAccessHash,
      String toChatId, String toAccessHash, List<int> messageIds) async {
    await _post('/files/move', {
      'fromChatId': fromChatId,
      'fromAccessHash': fromAccessHash,
      'toChatId': toChatId,
      'toAccessHash': toAccessHash,
      'messageIds': messageIds,
    });
  }

  // ─── Backup ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> backupUploadBatch(
    String folderName,
    List<Map<String, String>> files,
  ) async {
    final data = await _post('/backup/upload-batch', {
      'folderName': folderName,
      'files': files,
    });
    return data;
  }

  Future<Map<String, dynamic>> getBackupProgress(String batchId) =>
      _get('/upload/$batchId/progress');

  // ─── Stats ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() => _get('/stats');

  // ─── Recents ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecents() async {
    final data = await _get('/recents');
    return List<Map<String, dynamic>>.from(data['files'] ?? []);
  }

  // ─── Trash ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> moveToTrash(
    List<int> messageIds,
    String sourceChatId,
    String sourceAccessHash,
  ) =>
      _post('/trash/move', {
        'messageIds': messageIds,
        'sourceChatId': sourceChatId,
        'sourceAccessHash': sourceAccessHash,
      });

  Future<List<Map<String, dynamic>>> getTrash() async {
    final data = await _get('/trash');
    return List<Map<String, dynamic>>.from(data['files'] ?? []);
  }

  Future<void> restoreFromTrash(List<int> messageIds) =>
      _post('/trash/restore', {'messageIds': messageIds});

  Future<Map<String, dynamic>> purgeTrash() =>
      _post('/trash/purge', {});

  // ─── Favorites ───────────────────────────────────────────────

  Future<void> addFavorite(
    int messageId,
    String sourceChatId,
    String sourceAccessHash,
  ) =>
      _post('/favorites/add', {
        'messageId': messageId,
        'sourceChatId': sourceChatId,
        'sourceAccessHash': sourceAccessHash,
      });

  Future<void> removeFavorite(int messageId) =>
      _post('/favorites/remove', {'messageId': messageId});

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final data = await _get('/favorites');
    return List<Map<String, dynamic>>.from(data['files'] ?? []);
  }

  void dispose() {
    _client.close();
  }
}
