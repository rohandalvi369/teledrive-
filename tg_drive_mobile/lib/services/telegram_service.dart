import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:handy_tdlib/handy_tdlib.dart';
import 'package:path_provider/path_provider.dart';
import 'tdlib_isolate.dart';

enum AuthStep { initializing, phone, code, password, ready, closed }

class TelegramService extends ChangeNotifier {
  static TelegramService? _instance;
  static TelegramService get instance => _instance!;

  static final int _kApiId = int.tryParse(dotenv.env['API_ID'] ?? '') ?? 0;
  static final String _kApiHash = dotenv.env['API_HASH'] ?? '';

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

  bool _loading = false;
  bool get loading => _loading;

  bool get isAuthenticated => _currentStep == AuthStep.ready;

  int _requestCounter = 0;
  StreamSubscription<Map<String, dynamic>>? _updateSub;

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
        _error =
            'No internet connection. Please check your network and try again.';
        _loading = false;
        _currentStep = AuthStep.phone;
        _authState = 'waitPhone';
        notifyListeners();
        return;
      }

      _updateSub?.cancel();
      if (_tdlib != null) {
        try {
          _tdlib!.dispose();
        } catch (_) {}
        _tdlib = null;
      }

      if (_kApiId == 0 || _kApiHash.isEmpty) {
        _error =
            'Missing API credentials. Build with --dart-define=API_ID=... --dart-define=API_HASH=...';
        _loading = false;
        _currentStep = AuthStep.phone;
        _authState = 'waitPhone';
        notifyListeners();
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/tdlib';
      await Directory(dbPath).create(recursive: true);

      _tdlib = TdlibIsolate();
      _updateSub = _tdlib!.updates.listen(_processUpdate);

      await _tdlib!.start(
        apiId: _kApiId,
        apiHash: _kApiHash,
        databasePath: dbPath,
      );

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

  Future<void> setPhoneNumber(String phone) async {
    if (_tdlib == null || !_tdlib!.isReady) return;

    _loading = true;
    _error = null;
    notifyListeners();

    if (!await _checkConnectivity()) {
      _error = 'No internet connection.';
      _loading = false;
      notifyListeners();
      return;
    }

    final normalized = phone.startsWith('+') ? phone : '+$phone';

    try {
      final response = await _tdlib!.sendRequest({
        '@type': 'setAuthenticationPhoneNumber',
        'phone_number': normalized,
        'settings': {
          '@type': 'phoneNumberAuthenticationSettings',
          'allow_flash_call': false,
          'allow_app_hash': false,
          'is_current_phone_number': false,
          'allow_sms_retriever_api': false,
        },
      });

      if (response['@type'] == 'error') {
        _handleErrorResponse(response);
        _loading = false;
        notifyListeners();
      }
    } on TimeoutException {
      _error = 'Request timed out. Check your connection.';
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to send phone number: $e';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> checkCode(String code) async {
    if (_tdlib == null || !_tdlib!.isReady) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _tdlib!.sendRequest({
        '@type': 'checkAuthenticationCode',
        'code': code,
      });

      if (response['@type'] == 'error') {
        _handleErrorResponse(response);
        _loading = false;
        notifyListeners();
      }
    } on TimeoutException {
      _error = 'Request timed out.';
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to check code: $e';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> checkPassword(String password) async {
    if (_tdlib == null || !_tdlib!.isReady) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _tdlib!.sendRequest({
        '@type': 'checkAuthenticationPassword',
        'password': password,
      });

      if (response['@type'] == 'error') {
        _handleErrorResponse(response);
        _loading = false;
        notifyListeners();
      }
    } on TimeoutException {
      _error = 'Request timed out.';
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to check password: $e';
      _loading = false;
      notifyListeners();
    }
  }

  void logout() {
    _tdlib?.send({'@type': 'logOut'});
  }

  Future<Map<String, dynamic>> execute(TdFunction function) async {
    final extra = 'ex${_requestCounter++}';
    final request = function.toJson(extra);
    try {
      return await _tdlib!.sendRequest(
        request,
        timeout: const Duration(seconds: 60),
      );
    } on TimeoutException {
      return {'@type': 'error', 'code': 408, 'message': 'Request timed out'};
    } catch (e) {
      return {'@type': 'error', 'message': '$e'};
    }
  }

  Future<Map<String, dynamic>> sendMessageAndWait(
    int chatId,
    InputMessageContent content,
  ) async {
    return execute(
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
  }

  void _processUpdate(Map<String, dynamic> json) {
    final type = json['@type'] as String?;
    if (type == null) return;

    if (type == 'updateAuthorizationState') {
      final authStateRaw =
          json['authorization_state'] as Map<String, dynamic>?;
      if (authStateRaw != null) {
        final rawType = authStateRaw['@type'] as String?;
        debugPrint('AUTH: $rawType');

        switch (rawType) {
          case 'authorizationStateWaitPhoneNumber':
            _currentStep = AuthStep.phone;
            _authState = 'waitPhone';
            _loading = false;
            notifyListeners();
          case 'authorizationStateWaitCode':
            _currentStep = AuthStep.code;
            _authState = 'waitCode';
            _loading = false;
            notifyListeners();
          case 'authorizationStateWaitPassword':
            _hint = authStateRaw['password_hint'] as String?;
            _currentStep = AuthStep.password;
            _authState = 'waitPassword';
            _loading = false;
            notifyListeners();
          case 'authorizationStateReady':
            _currentStep = AuthStep.ready;
            _authState = 'ready';
            _loading = false;
            notifyListeners();
          case 'authorizationStateClosed':
            _currentStep = AuthStep.closed;
            _authState = 'closed';
            _initialized = false;
            notifyListeners();
          case 'authorizationStateWaitEncryptionKey':
            _tdlib?.send({
              '@type': 'checkDatabaseEncryptionKey',
              'encryption_key': '',
            });
          case 'authorizationStateWaitRegistration':
            _error =
                'Registration required. Please sign up in the official app first.';
            _loading = false;
            notifyListeners();
          case 'authorizationStateWaitOtherDeviceConfirmation':
            _error = 'Please confirm login from your Telegram app';
            _loading = false;
            notifyListeners();
          case 'authorizationStateLoggingOut':
            _currentStep = AuthStep.initializing;
            _authState = 'initializing';
            notifyListeners();
        }
      }
      return;
    }

    if (type == 'error' && json['@extra'] == null) {
      _handleErrorResponse(json);
      _loading = false;
      notifyListeners();
      return;
    }

    if (type == 'updateFile') {
      try {
        final object = convertJsonToObject(jsonEncode(json)) as UpdateFile;
        final file = object.file;

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
      } catch (_) {}
      return;
    }

    if (type == 'updateMessageSendSucceeded') {
      debugPrint('Message send confirmed');
      return;
    }
  }

  void _handleErrorResponse(Map<String, dynamic> response) {
    final message = response['message'] as String? ?? '';
    final code = response['code'] as int? ?? 0;

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
    } else if (message.contains('ALREADY_LOGGED_IN')) {
      _currentStep = AuthStep.ready;
      _authState = 'ready';
      _loading = false;
    } else {
      _error = message.contains('400') ? message : 'Error [$code]: $message';
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
