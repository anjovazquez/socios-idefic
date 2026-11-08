import '../../domain/onboarding/onboarding.dart';

String onboardingMessage(OnboardingFailure failure) => switch (failure) {
  InvalidPersonalDataFailure(field: PersonalField.firstName) =>
    'Escribe tu nombre',
  InvalidPersonalDataFailure(field: PersonalField.lastName) =>
    'Escribe tus apellidos',
  InvalidPersonalDataFailure(field: PersonalField.phone) =>
    'Revisa el teléfono: debe tener entre 9 y 15 cifras',
  InvalidPersonalDataFailure(field: PersonalField.birthDate) =>
    'Revisa la fecha de nacimiento',
  WeakPasswordFailure() =>
    'La contraseña debe tener al menos 8 caracteres, con letras y números',
  PasswordMismatchFailure() => 'Las contraseñas no coinciden',
  InvitationLinkExpiredFailure() =>
    'Este enlace ha caducado. Pide a tu club que te lo reenvíe',
  TermsNotAcceptedFailure() =>
    'Para continuar tienes que aceptar las condiciones',
  OnboardingUnavailableFailure() =>
    'No hemos podido conectar. Inténtalo de nuevo en un momento',
};
