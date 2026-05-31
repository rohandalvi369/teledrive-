import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// New TDLib JSON API: uses integer client IDs
typedef TdCreateClientIdC = Int32 Function();
typedef TdCreateClientIdDart = int Function();
typedef TdSendC = Void Function(Int32, Pointer<Utf8>);
typedef TdSendDart = void Function(int, Pointer<Utf8>);
typedef TdReceiveC = Pointer<Utf8> Function(Double);
typedef TdReceiveDart = Pointer<Utf8> Function(double);

class TdlibIsolate {
  SendPort? _cmdPort;
  late final ReceivePort _respPort;
  final StreamController<Map<String, dynamic>> _updates =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updates => _updates.stream;

  Future<void> start({
    required int apiId,
    required String apiHash,
    required String databasePath,
  }) async {
    _respPort = ReceivePort();

    final ready = Completer<void>();
    _respPort.listen((msg) {
      if (msg is Map && msg['@type'] == 'ready') {
        _cmdPort = msg['port'] as SendPort;
        ready.complete();
      } else if (msg is Map<String, dynamic>) {
        _updates.add(msg);
      } else if (msg is Map) {
        _updates.add(Map<String, dynamic>.from(msg));
      }
    });

    final params = {
      'api_id': apiId,
      'api_hash': apiHash,
      'database_path': databasePath,
    };

    await Isolate.spawn(
      _entry,
      {'send_port': _respPort.sendPort, 'params': params},
    );

    await ready.future.timeout(const Duration(seconds: 30));
  }

  bool sendRaw(Map<String, dynamic> request) {
    if (_cmdPort == null) {
      debugPrint('sendRaw: _cmdPort is null, dropping request ${request['@type']}');
      return false;
    }
    _cmdPort!.send({'command': 'send', 'json': jsonEncode(request)});
    return true;
  }

  void close() {
    _cmdPort?.send({'command': 'close'});
    _respPort.close();
    _updates.close();
  }

  void dispose() => close();
}

void _entry(Map<String, dynamic> msg) {
  final sendPort = msg['send_port'] as SendPort;
  final params = msg['params'] as Map<String, dynamic>;

  DynamicLibrary lib;
  try {
    lib = DynamicLibrary.open('libtdjson.so');
  } catch (e) {
    sendPort.send({'@type': 'error', 'message': 'open failed: $e'});
    return;
  }

  // Use the NEW TDLib API: integer client IDs, not pointers
  late int clientId;
  try {
    final fn = lib.lookupFunction<TdCreateClientIdC, TdCreateClientIdDart>(
        'td_create_client_id');
    clientId = fn();
  } catch (e) {
    sendPort.send({'@type': 'error', 'message': 'create client id failed: $e'});
    return;
  }

  final tdSend =
      lib.lookupFunction<TdSendC, TdSendDart>('td_send');
  final tdReceive =
      lib.lookupFunction<TdReceiveC, TdReceiveDart>('td_receive');

  final cmdPort = ReceivePort();
  sendPort.send({'@type': 'ready', 'port': cmdPort.sendPort});

  // Send setTdlibParameters immediately
  _sendInit(tdSend, clientId, params);
  _drain(tdReceive, sendPort);

  cmdPort.listen((cmd) {
    if (cmd is Map) {
      if (cmd['command'] == 'send') {
        final json = cmd['json'] as String;
        final ptr = json.toNativeUtf8();
        tdSend(clientId, ptr);
        calloc.free(ptr);
        _drain(tdReceive, sendPort);
      } else if (cmd['command'] == 'close') {
        cmdPort.close();
      }
    }
  });

  // Periodically poll for unsolicited updates
  Timer.periodic(const Duration(milliseconds: 300), (_) {
    _drain(tdReceive, sendPort);
  });
}

void _sendInit(TdSendDart tdSend, int clientId, Map<String, dynamic> params) {
  final apiId = params['api_id'] as int;
  final apiHash = params['api_hash'] as String;
  final dbPath = params['database_path'] as String;

  final request = {
    '@type': 'setTdlibParameters',
    'database_directory': '$dbPath/db',
    'files_directory': '$dbPath/files',
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

  var ptr = jsonEncode(request).toNativeUtf8();
  tdSend(clientId, ptr);
  calloc.free(ptr);

  // Also check database encryption key so TDLib progresses past WaitEncryptionKey
  final encRequest = {
    '@type': 'checkDatabaseEncryptionKey',
    'encryption_key': '',
  };
  ptr = jsonEncode(encRequest).toNativeUtf8();
  tdSend(clientId, ptr);
  calloc.free(ptr);
}

void _drain(TdReceiveDart tdReceive, SendPort sendPort) {
  for (int i = 0; i < 30; i++) {
    final ptr = tdReceive(0.01);
    if (ptr == nullptr) break;
    final str = ptr.toDartString();
    try {
      sendPort.send(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('TDLib parse error: $e');
    }
  }
}
