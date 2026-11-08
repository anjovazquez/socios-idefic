import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/auth/auth_failures.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-001.md — Acceso multi-club.
void main() {
  late FakeAuthRepository auth;
  late FakeClubRepository clubs;
  late InMemoryActiveClubStore store;

  setUp(() {
    auth = FakeAuthRepository(
      passwords: {
        'ana@example.com': 'ana-password',
        'luis@example.com': 'luis-password',
        'eva@example.com': 'eva-password',
      },
    );
    clubs = FakeClubRepository({
      'ana@example.com': [idefic],
      'luis@example.com': [demo, idefic],
    });
    store = InMemoryActiveClubStore();
  });

  Future<void> pumpApp(WidgetTester tester, {String? initialLocation}) async {
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs, store: store),
        initialLocation: initialLocation,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('a user with one club enters it directly', (tester) async {
    await pumpApp(tester);

    await signIn(tester, 'ana@example.com', 'ana-password');

    expect(find.text('IDEFIC'), findsWidgets);
    expect(find.text('Socio nº 2'), findsOneWidget);
    expect(find.byKey(const Key('switch-club')), findsNothing);
  });

  testWidgets('a user with several clubs chooses one and can switch without '
      'signing in again', (tester) async {
    await pumpApp(tester);

    await signIn(tester, 'luis@example.com', 'luis-password');

    expect(find.text('Elige tu club'), findsOneWidget);
    expect(find.byKey(const Key('club-IDEFIC')), findsOneWidget);
    expect(find.byKey(const Key('club-DEMO')), findsOneWidget);

    await tester.tap(find.byKey(const Key('club-DEMO')));
    await tester.pumpAndSettle();
    expect(find.text('Club Demo'), findsWidgets);
    expect(find.text('Socio nº 7'), findsOneWidget);

    await tester.tap(find.byKey(const Key('switch-club')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('club-IDEFIC')));
    await tester.pumpAndSettle();

    expect(find.text('Socio nº 2'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsNothing);
    expect(store.value, idefic.id);
  });

  testWidgets('wrong password shows an error and stays on login', (
    tester,
  ) async {
    await pumpApp(tester);

    await signIn(tester, 'ana@example.com', 'nope');

    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('network problems show a friendly message', (tester) async {
    auth.failure = const AuthUnavailableFailure();
    await pumpApp(tester);

    await signIn(tester, 'ana@example.com', 'ana-password');

    expect(
      find.text('No hemos podido conectar. Inténtalo de nuevo en un momento'),
      findsOneWidget,
    );
  });

  testWidgets('login offers no public sign up', (tester) async {
    await pumpApp(tester);

    expect(find.textContaining('Crear cuenta'), findsNothing);
    expect(find.textContaining('Registr'), findsNothing);
    expect(find.textContaining('Tu club te enviará una invitación'), findsOne);
  });

  testWidgets('protected routes redirect to login without a session', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: '/club');

    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('a user without active clubs is told so', (tester) async {
    await pumpApp(tester);

    await signIn(tester, 'eva@example.com', 'eva-password');

    expect(find.text('Todavía no tienes ningún club'), findsOneWidget);
  });

  testWidgets('logout returns to login', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'ana@example.com', 'ana-password');

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(store.value, isNull);
  });
}
