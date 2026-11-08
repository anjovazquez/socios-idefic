import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/onboarding/onboarding.dart';
import '../../domain/profile/my_profile.dart';
import '../club/image_picking.dart';
import '../onboarding/onboarding_messages.dart';

class MyDataViewModel extends ChangeNotifier {
  MyDataViewModel(this._useCases, {required this.pickImage});

  final AppUseCases _useCases;
  final PickImage pickImage;

  MyProfile? _profile;
  MyProfile? get profile => _profile;

  /// Photo shown and saved; may differ from [profile] until saving.
  String? _photoPath;
  String? _photoUrl;
  String? get photoUrl => _photoUrl;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    await _guard(() async {
      final profile = await _useCases.getMyProfile();
      _profile = profile;
      _photoPath = profile.photoPath;
      _photoUrl = profile.photoUrl;
    });
    _isLoading = false;
    notifyListeners();
  }

  Future<void> changePhoto() async {
    final picked = await pickImage();
    if (picked == null) return;
    _isBusy = true;
    notifyListeners();
    await _guard(() async {
      final stored = await _useCases.uploadProfilePhoto(
        bytes: picked.bytes,
        contentType: picked.contentType,
      );
      _photoPath = stored.path;
      _photoUrl = stored.url;
    });
    _isBusy = false;
    notifyListeners();
  }

  void removePhoto() {
    _photoPath = null;
    _photoUrl = null;
    notifyListeners();
  }

  /// Returns true when saved.
  Future<bool> save({
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime? birthDate,
  }) async {
    _isBusy = true;
    notifyListeners();
    final saved = await _guard(
      () => _useCases.updateMyProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        birthDate: birthDate,
        photoPath: _photoPath,
      ),
    );
    _isBusy = false;
    notifyListeners();
    return saved;
  }

  Future<bool> _guard(Future<void> Function() action) async {
    _error = null;
    try {
      await action();
      return true;
    } on OnboardingFailure catch (failure) {
      _error = onboardingMessage(failure);
    } on InvalidPhotoFailure {
      _error = 'La foto debe ser PNG, JPG o WebP y pesar menos de 2 MB';
    } catch (_) {
      _error = 'No hemos podido conectar. Inténtalo de nuevo en un momento';
    }
    return false;
  }
}
