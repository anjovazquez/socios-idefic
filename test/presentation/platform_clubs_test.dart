import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/platform/platform_club.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-003.md — Gestión de clubes.
void main() {
  late FakeAuthRepository auth;
  late FakeClubRepository clubs;
  late FakePlatformRepository platform;

  setUp(() {
    auth = FakeAuthRepository(
      passwords: {
        'root@example.com': 'root-password',
        'admin@example.com': 'admin-password',
      },
    );
    clubs = FakeClubRepository({
      'admin@example.com': [idefic],
    });
    platform = FakePlatformRepository(
      adminEmails: {'root@example.com'},
      existingUsers: {'admin@cou.es'},
      clubs: [
        const PlatformClub(
          id: 'club-idefic',
          name: 'IDEFIC',
          code: 'IDEFIC',
          isActive: true,
          memberCount: 3,
          adminEmail: 'admin@example.com',
        ),
        const PlatformClub(
          id: 'club-demo',
          name: 'Club Demo',
          code: 'DEMO',
          isActive: true,
          memberCount: 1,
        ),
      ],
    );
  });

  Future<void> signInAs(WidgetTester tester, String email) async {
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs, platform: platform),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(
      find.byKey(const Key('login-password')),
      email == 'root@example.com' ? 'root-password' : 'admin-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  Future<void> openPlatform(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-platform')));
    await tester.pumpAndSettle();
  }

  Future<void> fillClubForm(
    WidgetTester tester, {
    required String name,
    required String code,
    required String adminEmail,
  }) async {
    await tester.tap(find.byKey(const Key('new-club')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('club-form-name')), name);
    await tester.enterText(find.byKey(const Key('club-form-code')), code);
    await tester.enterText(
      find.byKey(const Key('club-form-admin-email')),
      adminEmail,
    );
    await tester.tap(find.byKey(const Key('club-form-save')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseMenu(WidgetTester tester, String code, String item) async {
    await tester.tap(find.byKey(Key('platform-club-menu-$code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('platform admin creates a club with its administrator', (
    tester,
  ) async {
    await signInAs(tester, 'root@example.com');
    await openPlatform(tester);

    await fillClubForm(
      tester,
      name: 'Club Ourense',
      code: 'cou',
      adminEmail: 'admin@cou.es',
    );

    expect(find.text('Club creado'), findsOneWidget);
    final tile = find.byKey(const Key('platform-club-COU'));
    expect(
      find.descendant(of: tile, matching: find.text('Activo')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tile,
        matching: find.textContaining('Admin: admin@cou.es'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unknown admin email stays pending', (tester) async {
    await signInAs(tester, 'root@example.com');
    await openPlatform(tester);

    await fillClubForm(
      tester,
      name: 'Club Nuevo',
      code: 'NUEVO',
      adminEmail: 'nadie@example.com',
    );

    expect(
      find.textContaining('Admin pendiente de alta: nadie@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('duplicate code keeps the form open with a message', (
    tester,
  ) async {
    await signInAs(tester, 'root@example.com');
    await openPlatform(tester);

    await fillClubForm(
      tester,
      name: 'Otro',
      code: 'idefic',
      adminEmail: 'otro@example.com',
    );

    expect(find.text('Ese código ya está en uso'), findsOneWidget);
    expect(find.byKey(const Key('club-form-save')), findsOneWidget);
  });

  testWidgets('deactivating a club keeps it listed and removes it from the '
      'selector', (tester) async {
    await signInAs(tester, 'root@example.com');
    expect(find.byKey(const Key('club-DEMO')), findsOneWidget);
    await openPlatform(tester);

    await chooseMenu(tester, 'DEMO', 'Desactivar');
    await tester.tap(find.byKey(const Key('confirm-deactivate')));
    await tester.pumpAndSettle();

    final tile = find.byKey(const Key('platform-club-DEMO'));
    expect(
      find.descendant(of: tile, matching: find.text('Desactivado')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Volver a mis clubes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('club-DEMO')), findsNothing);
    expect(find.byKey(const Key('club-IDEFIC')), findsOneWidget);
  });

  testWidgets('platform admin edits and enters a club', (tester) async {
    await signInAs(tester, 'root@example.com');
    await openPlatform(tester);

    await chooseMenu(tester, 'DEMO', 'Editar');
    await tester.enterText(
      find.byKey(const Key('club-form-name')),
      'Club Demo Renovado',
    );
    await tester.tap(find.byKey(const Key('club-form-save')));
    await tester.pumpAndSettle();
    expect(find.text('Club Demo Renovado'), findsOneWidget);

    await chooseMenu(tester, 'DEMO', 'Entrar como administrador');
    expect(find.text('Club Demo Renovado'), findsWidgets);
    expect(find.byKey(const Key('open-platform')), findsOneWidget);
  });

  testWidgets('a club admin does not see the platform', (tester) async {
    await signInAs(tester, 'admin@example.com');

    expect(find.text('Socio nº 2'), findsOneWidget);
    expect(find.byKey(const Key('open-platform')), findsNothing);
  });

  testWidgets('a platform admin without clubs lands on the platform', (
    tester,
  ) async {
    platform.clubs.clear();
    await signInAs(tester, 'root@example.com');

    expect(find.text('Plataforma · Clubes'), findsOneWidget);
    expect(find.text('Todavía no hay clubes. Crea el primero.'), findsOne);
  });
}
