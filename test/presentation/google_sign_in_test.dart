import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-002.md — Acceso con Google.
void main() {
  late FakeAuthRepository auth;
  late FakeClubRepository clubs;

  setUp(() {
    auth = FakeAuthRepository(passwords: {'ana@example.com': 'ana-password'});
    clubs = FakeClubRepository({
      'ana@example.com': [idefic],
    });
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapGoogle(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pumpAndSettle();
  }

  testWidgets('an existing member enters with Google', (tester) async {
    auth.googleEmail = 'ana@example.com';
    await pumpApp(tester);

    expect(find.text('Continuar con Google'), findsOneWidget);
    await tapGoogle(tester);

    expect(find.text('Socio nº 2'), findsOneWidget);
  });

  testWidgets('an unknown Google account is told to ask its club and gets no '
      'club', (tester) async {
    auth.googleEmail = 'nadie@example.com';
    await pumpApp(tester);

    await tapGoogle(tester);

    expect(
      find.text('Tu club todavía no te ha dado de alta con ese email'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('password and Google lead to the same account', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'ana@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'ana-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    final passwordUserId = auth.currentUser!.id;

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    auth.googleEmail = 'ana@example.com';
    await tapGoogle(tester);

    expect(auth.currentUser!.id, passwordUserId);
    expect(find.text('Socio nº 2'), findsOneWidget);
  });

  testWidgets('cancelling Google shows no error', (tester) async {
    await pumpApp(tester);

    await tapGoogle(tester);

    expect(auth.googleAttempts, 1);
    expect(find.textContaining('incorrectos'), findsNothing);
    expect(find.textContaining('dado de alta'), findsNothing);
  });

  testWidgets('a previous Google rejection is cleared on a new attempt', (
    tester,
  ) async {
    auth.googleEmail = 'nadie@example.com';
    await pumpApp(tester);
    await tapGoogle(tester);

    auth.googleEmail = 'ana@example.com';
    await tapGoogle(tester);

    expect(find.text('Socio nº 2'), findsOneWidget);
  });
}
