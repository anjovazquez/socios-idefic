import 'package:flutter/foundation.dart';

import '../../application/auth/sign_in_with_google.dart';
import '../../application/auth/sign_in_with_password.dart';
import '../../domain/auth/auth_failures.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._signIn, this._signInWithGoogle);

  final SignInWithPassword _signIn;
  final SignInWithGoogle _signInWithGoogle;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> submit({required String email, required String password}) =>
      _run(() => _signIn(email: email, password: password));

  Future<void> signInWithGoogle() => _run(_signInWithGoogle.call);

  Future<void> _run(Future<void> Function() action) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } on AuthFailure catch (failure) {
      _errorMessage = messageFor(failure);
    } catch (_) {
      _errorMessage = messageFor(const AuthUnavailableFailure());
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// User-facing copy for a failure; null when nothing needs to be said.
  static String? messageFor(AuthFailure failure) => switch (failure) {
    InvalidCredentialsFailure() => 'Email o contraseña incorrectos',
    MissingCredentialsFailure() => 'Escribe tu email y tu contraseña',
    UnregisteredAccountFailure() =>
      'Tu club todavía no te ha dado de alta con ese email',
    SignInCancelledFailure() => null,
    AuthUnavailableFailure() =>
      'No hemos podido conectar. Inténtalo de nuevo en un momento',
  };
}
