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

  AuthStep _currentStep = AuthStep.initializing;
  AuthStep get currentStep => _currentStep;

  String? _error;
  String? get error => _error;

  String? _hint;
  String? get hint => _hint;

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

  Future<void> initialize() async {
    if (_initialized) return;
    _currentStep = AuthStep.initializing;
    _loading = true;
    notifyListeners();

    try {
      _updateSub?.cancel();
      if (_tdlib != null) {
        try { _tdlib!.dispose(); } catch (_) {}
        _tdlib = null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/tdlib';
      await Directory(dbPath).create(recursive: true);

      _tdlib = TdlibIsolate();

      _updateSub = _tdlib!.updates.listen(_processUpdate);

      try {
        await _tdlib!.start(
          apiId: _kApiId,
          apiHash: _kApiHash,
          databasePath: dbPath,
        );
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('already in use') || msg.contains('td.binlog') || msg.contains('400')) {
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
      notifyListeners();
    }
  }

  void setPhoneNumber(String phone) {
    _loading = true;
    _error = null;
    notifyListeners();
    _sendRequest('setAuthenticationPhoneNumber', {
      'phone_number': phone,
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
    notifyListeners();
    _sendRequest('checkAuthenticationCode', {'code': code});
  }

  void checkPassword(String password) {
    _loading = true;
    _error = null;
    notifyListeners();
    _sendRequest('checkAuthenticationPassword', {'password': password});
  }

  void logout() {
    _sendRequest('logOut', {});
  }

  void _sendRequest(String type, Map<String, dynamic> params) {
    final request = <String, dynamic>{'@type': type}..addAll(params);
    _sendJson(request);
  }

  void _sendJson(Map<String, dynamic> request) {
    _tdlib?.sendRaw(request);
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
          _error = 'Invalid phone number';
        } else if (message.contains('PHONE_CODE_INVALID')) {
          _error = 'Invalid verification code';
        } else if (message.contains('PASSWORD_HASH_INVALID')) {
          _error = 'Invalid 2FA password';
        } else if (message.contains('API_ID_INVALID')) {
          _error = 'Invalid API ID';
        } else if (code == 429) {
          _error = 'Too many attempts. Try again later.';
        } else if (message.contains('SESSION_PASSWORD_NEEDED')) {
          _error = message;
        } else if (message.contains('ALREADY_LOGGED_IN')) {
          _currentStep = AuthStep.ready;
          _loading = false;
          notifyListeners();
          return;
        } else {
          _error = 'Error [$code]: $message';
        }

        if (_currentStep == AuthStep.phone ||
            _currentStep == AuthStep.code ||
            _currentStep == AuthStep.password) {
          _loading = false;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('TDLib process error for $type: $e');
    }
  }

  void _handleAuthState(AuthorizationState state) {
    switch (state) {
      case AuthorizationStateWaitTdlibParameters():
        // Already sent during init, ignore
        break;
      case AuthorizationStateWaitPhoneNumber():
        _currentStep = AuthStep.phone;
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateWaitCode():
        _currentStep = AuthStep.code;
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
        _loading = false;
        notifyListeners();
        break;
      case AuthorizationStateReady():
        _currentStep = AuthStep.ready;
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
        _initialized = false;
        notifyListeners();
        break;
      case AuthorizationStateLoggingOut():
        _currentStep = AuthStep.initializing;
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
    _updateSub?.cancel();
    _tdlib?.dispose();
    super.dispose();
  }
}
