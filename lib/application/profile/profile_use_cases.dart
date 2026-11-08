import 'dart:typed_data';

import '../../domain/onboarding/onboarding.dart';
import '../../domain/profile/my_profile.dart';
import '../../domain/profile/profile_repository.dart';

class GetMyProfile {
  const GetMyProfile(this._repository);

  final ProfileRepository _repository;

  Future<MyProfile> call() => _repository.getMyProfile();
}

class UpdateMyProfile {
  const UpdateMyProfile(this._repository);

  final ProfileRepository _repository;

  /// Validates with the same rules as the first access ([PersonalData]).
  Future<void> call({
    required String firstName,
    required String lastName,
    String? phone,
    DateTime? birthDate,
    String? photoPath,
  }) => _repository.updateMyProfile(
    data: PersonalData(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      birthDate: birthDate,
    ),
    photoPath: photoPath,
  );
}

class UploadProfilePhoto {
  const UploadProfilePhoto(this._repository);

  static const maxBytes = 2 * 1024 * 1024;
  static const allowedTypes = {'image/png', 'image/jpeg', 'image/webp'};

  final ProfileRepository _repository;

  Future<({String path, String url})> call({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        !allowedTypes.contains(contentType)) {
      throw const InvalidPhotoFailure();
    }
    final path = await _repository.uploadPhoto(
      bytes: bytes,
      contentType: contentType,
    );
    return (path: path, url: await _repository.photoUrl(path));
  }
}
