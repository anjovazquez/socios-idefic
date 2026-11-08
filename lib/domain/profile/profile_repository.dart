import 'dart:typed_data';

import '../onboarding/onboarding.dart';
import 'my_profile.dart';

abstract interface class ProfileRepository {
  Future<MyProfile> getMyProfile();

  Future<void> updateMyProfile({
    required PersonalData data,
    required String? photoPath,
  });

  /// Stores the photo in the private folder of the person; returns its path.
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String contentType,
  });

  /// Short-lived URL to show a private photo.
  Future<String> photoUrl(String path);
}
