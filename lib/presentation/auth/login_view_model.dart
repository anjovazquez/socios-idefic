import 'package:flutter/foundation.dart';

import '../../application/auth/sign_in_with_password.dart';
import '../../domain/auth/auth_failures.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._signIn);

  final SignInWithPassword _signIn;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> submit({required String email, required String password}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _signIn(email: email, password: password);
    } on AuthFailure catch (failure) {
      _errorMessage = messageFor(failure);
    } catch (_) {
      _errorMessage = messageFor(const AuthUnavailableFailure());
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  static String messageFor(AuthFailure failure) => switch (failure) {
    InvalidCredentialsFailure() => 'Email o contraseña incorrectos',
    MissingCredentialsFailure() => 'Escribe tu email y tu contraseña',
    AuthUnavailableFailure() =>
      'No hemos podido conectar. Inténtalo de nuevo en un momento',
  };
}
