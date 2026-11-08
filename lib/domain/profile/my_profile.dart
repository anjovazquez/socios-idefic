/// The signed-in person's own data (RF-005). The email is the login and is
/// never edited here.
class MyProfile {
  const MyProfile({
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.birthDate,
    this.photoPath,
    this.photoUrl,
  });

  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final DateTime? birthDate;

  /// Private storage path and a short-lived URL to show it.
  final String? photoPath;
  final String? photoUrl;
}

sealed class ProfileFailure implements Exception {
  const ProfileFailure();
}

/// Not PNG/JPEG/WebP or bigger than 2 MB.
final class InvalidPhotoFailure extends ProfileFailure {
  const InvalidPhotoFailure();
}

final class ProfileUnavailableFailure extends ProfileFailure {
  const ProfileUnavailableFailure([this.cause]);

  final Object? cause;
}
