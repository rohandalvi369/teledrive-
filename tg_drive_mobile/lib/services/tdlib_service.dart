import 'dart:convert';
import 'package:handy_tdlib/handy_tdlib.dart';

class TdlibService {
  late final TdPlugin _plugin;
  int? _clientId;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  int? get clientId => _clientId;

  Future<void> initialize() async {
    await TdPlugin.initialize();
    _plugin = TdPlugin.instance;
    _clientId = _plugin.tdCreateClientId();
    _initialized = true;
  }

  TdPlugin get plugin {
    if (!_initialized) throw StateError('TDLib not initialized');
    return _plugin;
  }

  void send(Map<String, dynamic> request) {
    if (_clientId == null) throw StateError('No client ID');
    _plugin.tdSend(_clientId!, jsonEncode(request));
  }

  String? receive([double timeout = 10.0]) {
    return _plugin.tdReceive(timeout);
  }

  Future<void> close() async {
    if (_initialized) {
      _initialized = false;
      _clientId = null;
    }
  }
}
