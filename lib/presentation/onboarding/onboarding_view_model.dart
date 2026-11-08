import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/onboarding/onboarding.dart';
import 'onboarding_messages.dart';

enum OnboardingStep { password, personalData, terms }

/// The three steps of RF-003: password (unless Google), data, conditions.
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel(
    this._useCases, {
    required this.status,
    required this.onCompleted,
  }) : _step = status.needsPassword
           ? OnboardingStep.password
           : OnboardingStep.personalData;

  final AppUseCases _useCases;
  final OnboardingStatus status;

  /// Reloads the session so the clubs become reachable.
  final Future<void> Function() onCompleted;

  OnboardingStep _step;
  OnboardingStep get step => _step;

  List<OnboardingStep> get steps => [
    if (status.needsPassword) OnboardingStep.password,
    OnboardingStep.personalData,
    OnboardingStep.terms,
  ];

  PersonalData? _data;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _error;
  String? get error => _error;

  Future<void> submitPassword(String password, String repeated) =>
      _run(() async {
        await _useCases.setNewPassword(password: password, repeated: repeated);
        _step = OnboardingStep.personalData;
      });

  Future<void> submitPersonalData({
    required String firstName,
    required String lastName,
    String? phone,
    DateTime? birthDate,
  }) => _run(() async {
    _data = PersonalData(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      birthDate: birthDate,
    );
    _step = OnboardingStep.terms;
  });

  void backToPersonalData() {
    _step = OnboardingStep.personalData;
    _error = null;
    notifyListeners();
  }

  Future<void> accept({required bool accepted}) => _run(() async {
    await _useCases.completeOnboarding(
      data: _data!,
      termsVersion: status.termsVersion,
      termsAccepted: accepted,
    );
    await onCompleted();
  });

  Future<void> _run(Future<void> Function() action) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on OnboardingFailure catch (failure) {
      _error = onboardingMessage(failure);
    } catch (_) {
      _error = onboardingMessage(const OnboardingUnavailableFailure());
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
