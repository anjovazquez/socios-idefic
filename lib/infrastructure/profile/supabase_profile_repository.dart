import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/onboarding/onboarding.dart';
import '../../domain/profile/my_profile.dart';
import '../../domain/profile/profile_repository.dart';
import '../onboarding/supabase_onboarding_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  static const bucket = 'profile-photos';
  static const _urlLifetime = Duration(hours: 1);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<MyProfile> getMyProfile() => _guard(() async {
    // RLS: everyone reads only their own profile row.
    final row = await _client
        .from('profiles')
        .select('email, first_name, last_name, phone, birth_date, photo_path')
        .eq('id', _userId)
        .single();
    final path = row['photo_path'] as String?;
    return myProfileFromRow(
      row,
      photoUrl: path == null ? null : await photoUrl(path),
    );
  });

  @override
  Future<void> updateMyProfile({
    required PersonalData data,
    required String? photoPath,
  }) => _guard(
    () => _client.rpc<void>(
      'update_my_profile',
      params: {
        'p_first_name': data.firstName,
        'p_last_name': data.lastName,
        'p_phone': data.phone,
        'p_birth_date': data.birthDate?.toIso8601String().substring(0, 10),
        'p_photo_path': photoPath,
      },
    ),
  );

  @override
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String contentType,
  }) => _guard(() async {
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        '$_userId/photo-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  });

  @override
  Future<String> photoUrl(String path) => _guard(
    () => _client.storage
        .from(bucket)
        .createSignedUrl(path, _urlLifetime.inSeconds),
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      if (error.message.contains('photo')) throw const InvalidPhotoFailure();
      throw mapOnboardingDbError(error.code, error.message, error.hint);
    } on StorageException catch (error) {
      throw switch (error.statusCode) {
        '413' || '415' => const InvalidPhotoFailure(),
        _ => ProfileUnavailableFailure(error),
      };
    } on ProfileFailure {
      rethrow;
    } on OnboardingFailure {
      rethrow;
    } catch (error) {
      throw ProfileUnavailableFailure(error);
    }
  }
}

MyProfile myProfileFromRow(Map<String, dynamic> row, {String? photoUrl}) =>
    MyProfile(
      email: row['email'] as String,
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      phone: row['phone'] as String?,
      birthDate: switch (row['birth_date']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      photoPath: row['photo_path'] as String?,
      photoUrl: photoUrl,
    );
