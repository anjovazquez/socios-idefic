import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/onboarding/onboarding.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-007.md — Primer acceso.
void main() {
  late FakeAuthRepository auth;
  late FakeClubRepository clubs;
  late FakeOnboardingRepository onboarding;

  OnboardingStatus pendingFor(String email, {bool needsPassword = true}) =>
      OnboardingStatus(
        completed: false,
        needsPassword: needsPassword,
        termsVersion: '2026-11-v1',
        email: email,
        firstName: 'Marta',
      );

  setUp(() {
    auth = FakeAuthRepository(passwords: {'marta@example.com': 'old'});
    clubs = FakeClubRepository();
    onboarding = FakeOnboardingRepository(
      pending: {
        'marta@example.com': pendingFor('marta@example.com'),
        'gmail@example.com': pendingFor(
          'gmail@example.com',
          needsPassword: false,
        ),
      },
      linkTokens: {'good-token': 'marta@example.com'},
      clubsOnCompletion: {
        'marta@example.com': [idefic],
        'gmail@example.com': [idefic],
      },
    );
  });

  Future<void> pumpApp(WidgetTester tester, {String? initialLocation}) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: auth,
          clubs: clubs,
          onboarding: onboarding,
        ),
        initialLocation: initialLocation,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> fillData(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('onboarding-last-name')),
      'Gómez',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-phone')),
      '600 11 22 33',
    );
    await tap(tester, 'onboarding-data-next');
  }

  testWidgets('activation with a password', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/activar?token_hash=good-token&type=invite',
    );

    expect(find.text('Activa tu cuenta'), findsOneWidget);
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    expect(find.text('Crea tu contraseña'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-password')),
      'corta',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-password-repeat')),
      'corta',
    );
    await tap(tester, 'onboarding-password-next');
    expect(
      find.text(
        'La contraseña debe tener al menos 8 caracteres, con letras y números',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('onboarding-password')),
      'secreto123',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-password-repeat')),
      'secreto123',
    );
    await tap(tester, 'onboarding-password-next');
    expect(find.text('Tus datos'), findsOneWidget);
    // The name given by the club is prefilled.
    expect(find.text('Marta'), findsOneWidget);

    await fillData(tester);
    expect(find.text('Condiciones de uso'), findsOneWidget);

    await tap(tester, 'onboarding-accept');
    await tap(tester, 'onboarding-finish');

    expect(find.text('Socio nº 2'), findsOneWidget);
    expect(onboarding.passwords['marta@example.com'], 'secreto123');
    expect(onboarding.completedWith!.lastName, 'Gómez');
    expect(onboarding.completedWith!.phone, '600112233');
  });

  testWidgets('activation with Google skips the password', (tester) async {
    auth = FakeAuthRepository(passwords: {'gmail@example.com': 'google'});
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'gmail@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'google');
    await tap(tester, 'login-submit');

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.text('Tus datos'), findsOneWidget);
    expect(find.text('Crea tu contraseña'), findsNothing);
  });

  testWidgets('the conditions cannot be skipped', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/activar?token_hash=good-token&type=invite',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-password')),
      'secreto123',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-password-repeat')),
      'secreto123',
    );
    await tap(tester, 'onboarding-password-next');
    await fillData(tester);

    await tap(tester, 'onboarding-finish');

    expect(
      find.text('Para continuar tienes que aceptar las condiciones'),
      findsOneWidget,
    );
    expect(onboarding.completedWith, isNull);
  });

  testWidgets('a member who left halfway returns to the first access', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: '/club');
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'marta@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'old');
    await tap(tester, 'login-submit');

    expect(find.text('Activa tu cuenta'), findsOneWidget);
    expect(find.text('Socio nº 2'), findsNothing);
  });

  testWidgets('an expired link explains what to do', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/activar?token_hash=used-token&type=invite',
    );

    expect(
      find.text('Este enlace ha caducado. Pide a tu club que te lo reenvíe'),
      findsOneWidget,
    );
    expect(find.text('Ir a iniciar sesión'), findsOneWidget);
  });
}
