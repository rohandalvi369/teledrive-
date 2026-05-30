import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final String? Function() onGetPhoneNumber;
  final String? Function() onGetCode;
  final String? Function() onGetPassword;

  AuthService({
    required this.onGetPhoneNumber,
    required this.onGetCode,
    required this.onGetPassword,
  });

  bool _authenticated = false;
  bool get isAuthenticated => _authenticated;

  String? _error;
  String? get error => _error;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> authenticate({
    required int apiId,
    required String apiHash,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 2));

      final phone = onGetPhoneNumber();
      if (phone == null) {
        _error = 'Phone number is required';
        _loading = false;
        notifyListeners();
        return;
      }

      final code = onGetCode();
      if (code == null) {
        _error = 'Verification code is required';
        _loading = false;
        notifyListeners();
        return;
      }

      _authenticated = true;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  void logout() {
    _authenticated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
