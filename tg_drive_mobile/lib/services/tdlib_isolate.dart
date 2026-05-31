import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/client.dart';

class TdlibIsolate {
  int _clientId = -1;
  bool _ready = false;
  Timer? _pollTimer;
  final StreamController<Map<String, dynamic>> _updates =
      StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  int _extraCounter = 0;

  Stream<Map<String, dynamic>> get updates => _updates.stream;
  bool get isReady => _ready;

  Future<void> start({
    required int apiId,
    required String apiHash,
    required String databasePath,
  }) async {
    try {
      await TdPlugin.initialize();
    } catch (e) {
      throw Exception('TdPlugin init failed: $e');
    }

    _clientId = TdPlugin.instance.tdCreateClientId();
    if (_clientId < 0) {
      throw Exception('Failed to create TDLib client');
    }

    _send({
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
    });

    _send({
      '@type': 'checkDatabaseEncryptionKey',
      'encryption_key': '',
    });

    _ready = true;

    _poll();

    _pollTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _poll();
    });
  }

  Future<Map<String, dynamic>> sendRequest(
    Map<String, dynamic> request, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final extra =
        request['@extra'] as String? ?? 'x${_extraCounter++}';
    request['@extra'] = extra;
    final completer = Completer<Map<String, dynamic>>();
    _pending[extra] = completer;

    _send(request);
    _poll();

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(extra);
      rethrow;
    }
  }

  void send(Map<String, dynamic> request) {
    _send(request);
    _poll();
  }

  void _send(Map<String, dynamic> request) {
    if (!_ready) {
      debugPrint('TDLIB: cannot send, not ready');
      return;
    }
    TdPlugin.instance.tdSend(_clientId, jsonEncode(request));
  }

  void _poll() {
    for (int i = 0; i < 50; i++) {
      try {
        final raw = TdPlugin.instance.tdReceive(0.005);
        if (raw == null) break;

        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final extra = decoded['@extra'] as String?;

        if (extra != null) {
          final completer = _pending.remove(extra);
          if (completer != null) {
            completer.complete(decoded);
            continue;
          }
        }

        _updates.add(decoded);
      } catch (e) {
        debugPrint('TDLIB poll error: $e');
        break;
      }
    }
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
