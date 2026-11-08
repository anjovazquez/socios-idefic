sealed class AuthFailure implements Exception {
  const AuthFailure();
}

/// Email or password do not match an existing account.
final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

/// Email or password were left empty.
final class MissingCredentialsFailure extends AuthFailure {
  const MissingCredentialsFailure();
}

/// The external account (Google) is not linked to anyone a club signed up
/// (RN-001: there is no public sign up).
final class UnregisteredAccountFailure extends AuthFailure {
  const UnregisteredAccountFailure();
}

/// The person closed the provider screen without finishing.
final class SignInCancelledFailure extends AuthFailure {
  const SignInCancelledFailure();
}

/// The auth service could not be reached or failed unexpectedly.
final class AuthUnavailableFailure extends AuthFailure {
  const AuthUnavailableFailure([this.cause]);

  final Object? cause;
}
