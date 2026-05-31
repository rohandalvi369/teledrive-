import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/handy_tdlib.dart';
import 'package:path_provider/path_provider.dart';
import 'tdlib_isolate.dart';

enum AuthStep { initializing, phone, code, password, ready, closed }

class TelegramService extends ChangeNotifier {
  static TelegramService? _instance;
  static TelegramService get instance => _instance!;

  static const int _kApiId = int.fromEnvironment('API_ID');
  static const String _kApiHash = String.fromEnvironment('API_HASH');

  TdlibIsolate? _tdlib;
  bool _initialized = false;

  String _authState = 'initializing';
  String get authState => _authState;

  AuthStep _currentStep = AuthStep.initializing;
  AuthStep get currentStep => _currentStep;

  String? _error;
  String? get error => _error;

  String? _hint;
  String? get hint => _hint;

  String? _dbPath;

  bool _loading = false;
  bool get loading => _loading;

  bool get isAuthenticated => _currentStep == AuthStep.ready;

  int _requestCounter = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  final Map<String, Completer<void>> _pendingSendConfirmations = {};

  double _uploadProgress = 0;
  double get uploadProgress => _uploadProgress;
  bool _isUploading = false;
  bool get isUploading => _isUploading;
  String _uploadFileName = '';
  String get uploadFileName => _uploadFileName;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;
  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;
  String _downloadFileName = '';
  String get downloadFileName => _downloadFileName;
  int _downloadingFileId = 0;

  StreamSubscription<Map<String, dynamic>>? _updateSub;

  TelegramService() {
    _instance = this;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('telegram.org')
          .timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) return true;
    } on SocketException catch (_) {
    } on TimeoutException catch (_) {
    }
    return false;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _currentStep = AuthStep.initializing;
    _authState = 'initializing';
    _loading = true;
    notifyListeners();

    try {
      if (!await _checkConnectivity()) {
        _error = 'No internet connection. Please check your network and try again.';
        _loading = false;
        _currentStep = AuthStep.phone;
        _authState = 'waitPhone';
        notifyListeners();
        return;
      }
      _updateSub?.cancel();
      if (_tdlib != null) {
        try { _tdlib!.dispose(); } catch (_) {}
        _tdlib = null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/tdlib';
      _dbPath = dbPath;
      await Directory(dbPath).create(recursive: true);

      _tdlib = TdlibIsolate();

      _updateSub = _tdlib!.updates.listen(_processUpdate);

      if (_kApiId == 0 || _kApiHash.isEmpty) {
        _error = 'Missing API credentials. Build with --dart-define=API_ID=... --dart-define=API_HASH=...';
        _loading = false;
        _currentStep = AuthStep.phone;
        _authState = 'waitPhone';
        notifyListeners();
        return;
      }

      try {
        await _tdlib!.start(
          apiId: _kApiId,
          apiHash: _kApiHash,
          databasePath: dbPath,
        );
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('already in use') || msg.contains('td.binlog')) {
          // Lock file issue — dispose and recreate once
          try { _tdlib!.dispose(); } catch (_) {}
          _tdlib = TdlibIsolate();
          _updateSub = _tdlib!.updates.listen(_processUpdate);
          await _tdlib!.start(
            apiId: _kApiId,
            apiHash: _kApiHash,
            databasePath: dbPath,
          );
        } else {
          rethrow;
        }
      }

      _initialized = true;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Init failed: $e';
      _loading = false;
      _currentStep = AuthStep.phone;
      _authState = 'waitPhone';
      notifyListeners();
    }
  }

  Timer? _loadingTimer;

  void _resetLoadingAfterTimeout({int seconds = 60}) {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(Duration(seconds: seconds), () {
      if (_loading) {
        _loading = false;
        _error = 'Connection timeout. Check your internet and try again.';
        debugPrint('_resetLoadingAfterTimeout fired after ${seconds}s');
        notifyListeners();
      }
    });
  }

  Future<void> setPhoneNumber(String phone) async {
    _loading = true;
    _error = null;
    _resetLoadingAfterTimeout();
    notifyListeners();
    if (!await _checkConnectivity()) {
      _error = 'No internet connection. Please check your network and try again.';
      _loading = false;
      _loadingTimer?.cancel();
      notifyListeners();
      return;
    }
    final normalized = phone.startsWith('+') ? phone : '+$phone';
    debugPrint('Sending code to: $normalized');
    debugPrint('Current authState: $_authState, step: $_currentStep');
    debugPrint('_cmdPort null? ${_tdlib == null ? "tdlib is null" : "tdlib ok"}');
    _sendAuthRequest('setAuthenticationPhoneNumber', {
      'phone_number': normalized,
      'settings': {
        '@type': 'phoneNumberAuthenticationSettings',
        'allow_flash_call': false,
        'allow_app_hash': false,
        'is_current_phone_number': false,
        'allow_sms_retriever_api': false,
      },
    });
  }

  void checkCode(String code) {
    _loading = true;
    _error = null;
    _resetLoadingAfterTimeout();
    notifyListeners();
    _sendAuthRequest('checkAuthenticationCode', {'code': code});
  }

  void checkPassword(String password) {
    _loading = true;
    _error = null;
    _resetLoadingAfterTimeout();
    notifyListeners();
    _sendAuthRequest('checkAuthenticationPassword', {'password': password});
  }

  void logout() {
    _sendRequest('logOut', {});
  }

  void _sendRequest(String type, Map<String, dynamic> params) {
    final request = <String, dynamic>{'@type': type}..addAll(params);
    try {
      _sendJson(request);
    } catch (e) {
      debugPrint('_sendRequest failed for $type: $e');
      _loadingTimer?.cancel();
      _loading = false;
      _error = 'TDLib communication error: $e';
      notifyListeners();
    }
  }

  void _sendAuthRequest(String type, Map<String, dynamic> params) {
    final extra = 'auth_${_requestCounter++}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[extra] = completer;
    final request = <String, dynamic>{'@type': type, '@extra': extra}..addAll(params);
    try {
      _sendJson(request);
    } catch (e) {
      debugPrint('_sendAuthRequest failed for $type: $e');
      _loadingTimer?.cancel();
      _loading = false;
      _error = 'TDLib communication error: $e';
      notifyListeners();
      return;
    }
    completer.future.timeout(const Duration(seconds: 60)).then((resp) {
      if (_loading) {
        _loadingTimer?.cancel();
        _loading = false;
        _error = null;
        notifyListeners();
      }
    }).catchError((e) {
      if (_loading) {
        _loadingTimer?.cancel();
        _loading = false;
        _error = 'Connection timeout. Check your internet and try again.';
        notifyListeners();
      }
    });
  }

  void _sendJson(Map<String, dynamic> request) {
    if (_tdlib == null) throw Exception('TDLib not initialized');
    if (!_tdlib!.sendRaw(request)) {
      throw Exception('TDLib isolate not ready (cmdPort is null)');
    }
  }

  Future<Map<String, dynamic>> sendMessageAndWait(
    int chatId,
    InputMessageContent content,
  ) async {
    final resp = await execute(
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: null,
        options: const MessageSendOptions(
          disableNotification: false,
          fromBackground: false,
          protectContent: false,
          updateOrderOfInstalledStickerSets: false,
          schedulingState: null,
          effectId: 0,
          sendingId: 0,
          onlyPreview: false,
        ),
        replyMarkup: null,
        inputMessageContent: content,
      ),
    );

    final tempId = resp['id'] as int?;
    if (tempId != null && tempId > 0) {
      final completer = Completer<void>();
      _pendingSendConfirmations['$chatId:$tempId'] = completer;
      try {
        await completer.future.timeout(const Duration(seconds: 30));
      } on TimeoutException {
        _pendingSendConfirmations.remove('$chatId:$tempId');
      }
    }

    return resp;
  }

  Future<Map<String, dynamic>> execute(TdFunction function) async {
    final completer = Completer<Map<String, dynamic>>();
    final extra = 'req_${_requestCounter++}';
    _pendingRequests[extra] = completer;

    _sendJson(function.toJson(extra));

    final timer = Timer(const Duration(seconds: 60), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('TDLib request timed out'));
        _pendingRequests.remove(extra);
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }

  void _processUpdate(Map<String, dynamic> json) {
    final type = json['@type'] as String?;
    if (type == null) return;

    final extra = json['@extra'] as String?;
    if (extra != null && _pendingRequests.containsKey(extra)) {
      _pendingRequests[extra]!.complete(json);
      _pendingRequests.remove(extra);
      return;
    }

    // Handle auth states that handy_tdlib 2.3.10 doesn't have typed classes for
    if (type == 'updateAuthorizationState') {
      final authStateRaw = json['authorization_state'] as Map<String, dynamic>?;
      if (authStateRaw != null) {
        final rawType = authStateRaw['@type'] as String?;
        debugPrint('Auth state update: $rawType, current step: $_currentStep');
        switch (rawType) {
          case 'authorizationStateWaitEncryptionKey':
            _sendJson({
              '@type': 'checkDatabaseEncryptionKey',
              'encryption_key': '',
            });
            return;
        }
      }
    }

    try {
      final object = convertJsonToObject(jsonEncode(json));

      if (type == 'updateAuthorizationState') {
        final authState =
            (object as UpdateAuthorizationState).authorizationState;
        _handleAuthState(authState);
      } else if (type == 'updateFile') {
        final updateFile = object as UpdateFile;
        final file = updateFile.file;

        if (file.remote.isUploadingActive ||
            file.remote.isUploadingCompleted) {
          _uploadProgress = file.expectedSize > 0
              ? file.remote.uploadedSize / file.expectedSize
              : 0;
          if (file.remote.isUploadingCompleted) {
            _uploadProgress = 1.0;
          }
          notifyListeners();
        }

        if (file.local.isDownloadingActive ||
            file.local.isDownloadingCompleted) {
          if (file.id == _downloadingFileId) {
            _downloadProgress = file.expectedSize > 0
                ? file.local.downloadedSize / file.expectedSize
                : 0;
            if (file.local.isDownloadingCompleted) {
              _downloadProgress = 1.0;
            }
            notifyListeners();
          }
        }
        } else if (type == 'updateMessageSendSucceeded') {
          final msg = json['message'] as Map<String, dynamic>?;
          if (msg != null) {
            final chatId = msg['chat_id'] as int?;
            final oldMsgId = json['old_message_id'] as int?;
            if (chatId != null && oldMsgId != null && oldMsgId > 0) {
              final key = '$chatId:$oldMsgId';
              final completer = _pendingSendConfirmations.remove(key);
              if (completer != null && !completer.isCompleted) {
                completer.complete();
              }
            }
          }
        } else if (type == 'error') {
        final err = object as TdError;
        final message = err.message;
        final code = err.code;

        if (message.contains('PHONE_NUMBER_INVALID')) {
          _error = 'Invalid phone number. Include country code (e.g. +1...)';
        } else if (message.contains('PHONE_CODE_INVALID')) {
          _error = 'Invalid verification code';
        } else if (message.contains('PHONE_CODE_EMPTY')) {
          _error = 'Verification code is empty';
        } else if (message.contains('PHONE_CODE_EXPIRED')) {
          _error = 'Verification code expired. Request a new one.';
        } else if (message.contains('PHONE_NUMBER_FLOOD')) {
          _error = 'Too many requests. Wait a few minutes and try again.';
        } else if (message.contains('PHONE_NUMBER_BANNED')) {
          _error = 'This phone number is banned from Telegram';
        } else if (message.contains('PASSWORD_HASH_INVALID')) {
          _error = 'Invalid 2FA password';
        } else if (message.contains('API_ID_INVALID')) {
          _error = 'Invalid API ID. Check your --dart-define values.';
        } else if (code == 429) {
          _error = 'Too many attempts. Try again later.';
        } else if (message.contains('SESSION_PASSWORD_NEEDED')) {
          _error = message;
        } else if (message.contains('ALREADY_LOGGED_IN')) {
          _currentStep = AuthStep.ready;
          _authState = 'ready';
          _loading = false;
          notifyListeners();
          return;
        } else {
          _error = message.contains('400') ? message : 'Error [$code]: $message';
        }

        if (_currentStep == AuthStep.phone ||
            _currentStep == AuthStep.code ||
            _currentStep == AuthStep.password) {
          _loadingTimer?.cancel();
          _loading = false;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('TDLib process error for $type: $e');
      if (_loading) {
        _loadingTimer?.cancel();
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _handleAuthState(AuthorizationState state) {
    _loadingTimer?.cancel();
    switch (state) {
      case AuthorizationStateWaitPhoneNumber():
        _currentStep = AuthStep.phone;
        _authState = 'waitPhone';
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateWaitCode():
        _currentStep = AuthStep.code;
        _authState = 'waitCode';
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateWaitOtherDeviceConfirmation():
        _error = 'Please confirm login from your Telegram app';
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateWaitPassword():
        _hint = state.passwordHint.isNotEmpty ? state.passwordHint : null;
        _currentStep = AuthStep.password;
        _authState = 'waitPassword';
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateReady():
        _currentStep = AuthStep.ready;
        _authState = 'ready';
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateWaitRegistration():
        _error =
            'Registration required. Please sign up in the official app first.';
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateClosed():
        _currentStep = AuthStep.closed;
        _authState = 'closed';
        _initialized = false;
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (_authState == 'closed') {
            initialize();
          }
        });
        break;
      case AuthorizationStateLoggingOut():
        _currentStep = AuthStep.initializing;
        _authState = 'initializing';
        notifyListeners();
        break;
      default:
        debugPrint('Unhandled auth state: ${state.currentObjectId}');
    }
  }

  void startUploadTracking(String fileName) {
    _isUploading = true;
    _uploadProgress = 0;
    _uploadFileName = fileName;
    notifyListeners();
  }

  void stopUploadTracking() {
    _isUploading = false;
    _uploadProgress = 0;
    _uploadFileName = '';
    notifyListeners();
  }

  void startDownloadTracking(String fileName, int fileId) {
    _isDownloading = true;
    _downloadProgress = 0;
    _downloadFileName = fileName;
    _downloadingFileId = fileId;
    notifyListeners();
  }

  void stopDownloadTracking() {
    _isDownloading = false;
    _downloadProgress = 0;
    _downloadFileName = '';
    _downloadingFileId = 0;
    notifyListeners();
  }

  Future<void> close() async {
    _updateSub?.cancel();
    _tdlib?.dispose();
    _initialized = false;
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _updateSub?.cancel();
    _tdlib?.dispose();
    super.dispose();
  }
}
