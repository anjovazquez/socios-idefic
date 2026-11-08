import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/auth/auth_failures.dart';
import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/auth_user.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client, {this.oauthRedirectUrl});

  final supabase.SupabaseClient _client;

  /// Where the provider sends the user back. Null on web keeps the current
  /// origin; mobile uses the app deep link.
  final String? oauthRedirectUrl;

  @override
  AuthUser? get currentUser => _toDomain(_client.auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _client.auth.onAuthStateChange
      .map((state) => _toDomain(state.session?.user))
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) => sink.addError(
            error is supabase.AuthException
                ? mapAuthException(error)
                : AuthUnavailableFailure(error),
            stackTrace,
          ),
        ),
      );

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = _toDomain(response.user);
      if (user == null) throw const AuthUnavailableFailure();
      return user;
    } on supabase.AuthException catch (error) {
      throw mapAuthException(error);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthUnavailableFailure(error);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final launched = await _client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: oauthRedirectUrl,
      );
      if (!launched) throw const SignInCancelledFailure();
    } on supabase.AuthException catch (error) {
      throw mapAuthException(error);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthUnavailableFailure(error);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  static AuthUser? _toDomain(supabase.User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email ?? '');
}

/// Maps Supabase Auth errors to domain failures.
AuthFailure mapAuthException(supabase.AuthException error) {
  final message = error.message.toLowerCase();
  if (error.code == 'signup_disabled' ||
      message.contains('signups not allowed')) {
    return const UnregisteredAccountFailure();
  }
  if (error.code == 'invalid_credentials' || error.statusCode == '400') {
    return const InvalidCredentialsFailure();
  }
  return AuthUnavailableFailure(error);
}
