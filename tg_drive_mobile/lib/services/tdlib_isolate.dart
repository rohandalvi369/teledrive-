import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/client.dart';

class TdlibIsolate {
  int _clientId = -1;
  bool _ready = false;
  Timer? _pollTimer;
  final StreamController<Map<String, dynamic>> _updates =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updates => _updates.stream;
  bool get isReady => _ready;

  Future<void> start({
    required int apiId,
    required String apiHash,
    required String databasePath,
  }) async {
    // Load libtdjson.so on main thread via TdPlugin
    try {
      await TdPlugin.initialize();
      debugPrint('TDLIB: TdPlugin initialized');
    } catch (e) {
      throw Exception('open failed: $e');
    }

    _clientId = TdPlugin.instance.tdCreateClientId();
    debugPrint('TDLIB: client created, id=$_clientId');

    final request = {
      '@type': 'setTdlibParameters',
      'database_directory': '$databasePath/db',
      'files_directory': '$databasePath/files',
      'use_test_dc': false,
      'api_id': apiId,
      'api_hash': apiHash,
      'system_language_code': 'en',
      'device_model':
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'system_version': Platform.operatingSystemVersion,
      'application_version': '1.0.0',
      'enable_storage_optimizer': true,
      'ignore_file_names': false,
    };
    _sendJson(request);

    final encRequest = {
      '@type': 'checkDatabaseEncryptionKey',
      'encryption_key': '',
    };
    _sendJson(encRequest);

    _ready = true;
    debugPrint('TDLIB: ready');

    // Drain any initial responses immediately
    _pollUpdates();

    // Periodic polling
    _pollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _pollUpdates();
    });

    // One extra drain after a short delay to catch init responses
    Future.delayed(const Duration(milliseconds: 100), _pollUpdates);
  }

  void _pollUpdates() {
    for (int i = 0; i < 30; i++) {
      try {
        final result = TdPlugin.instance.tdReceive(0.01);
        if (result == null) break;
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        _updates.add(decoded);
      } catch (e) {
        debugPrint('TDLIB: poll error: $e');
        break;
      }
    }
  }

  bool sendRaw(Map<String, dynamic> request) {
    if (!_ready) {
      debugPrint(
          'TDLIB: sendRaw FAIL - not ready, type=${request['@type']}');
      return false;
    }
    debugPrint('TDLIB: sendRaw type=${request['@type']}');
    _sendJson(request);
    _pollUpdates();
    return true;
  }

  void _sendJson(Map<String, dynamic> request) {
    final json = jsonEncode(request);
    TdPlugin.instance.tdSend(_clientId, json);
  }

  void close() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _ready = false;
  }

  void dispose() {
    close();
    _updates.close();
  }
}
