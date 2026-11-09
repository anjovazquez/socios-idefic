import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/platform/audit_entry.dart';
import 'package:socios_idefic/domain/platform/platform_club.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/platform/audit_labels.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-005.md — Suplantación funcional.
void main() {
  late FakeAuthRepository auth;
  late FakeClubRepository clubs;
  late FakePlatformRepository platform;

  setUp(() {
    auth = FakeAuthRepository(
      passwords: {'root@example.com': 'pw', 'admin@example.com': 'pw'},
    );
    clubs = FakeClubRepository({
      'admin@example.com': [ideficAsAdmin],
    });
    platform = FakePlatformRepository(
      adminEmails: {'root@example.com'},
      clubs: [
        const PlatformClub(
          id: 'club-idefic',
          name: 'IDEFIC',
          code: 'IDEFIC',
          isActive: true,
          memberCount: 3,
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
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs, platform: platform),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  Future<void> enterAsAdmin(WidgetTester tester, String code) async {
    await tester.tap(find.byKey(const Key('open-platform')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('platform-club-menu-$code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar como administrador'));
    await tester.pumpAndSettle();
  }

  testWidgets('the platform admin manages a club with a visible notice', (
    tester,
  ) async {
    await signInAs(tester, 'root@example.com');

    await enterAsAdmin(tester, 'DEMO');

    expect(find.byKey(const Key('impersonation-banner')), findsOneWidget);
    expect(
      find.textContaining('Estás administrando Club Demo'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-admin-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('impersonation-exit')));
    await tester.pumpAndSettle();

    expect(find.text('Plataforma · Clubes'), findsOneWidget);
    expect(find.byKey(const Key('impersonation-banner')), findsNothing);
  });

  testWidgets('a club admin in their own club sees no notice', (tester) async {
    await signInAs(tester, 'admin@example.com');

    expect(find.byKey(const Key('impersonation-banner')), findsNothing);
    expect(find.byKey(const Key('open-platform')), findsNothing);
  });

  testWidgets('the audit log shows who acted and that it was as platform', (
    tester,
  ) async {
    await signInAs(tester, 'root@example.com');
    await tester.tap(find.byKey(const Key('open-platform')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('platform-club-menu-DEMO')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-deactivate')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-audit')));
    await tester.pumpAndSettle();

    expect(find.text('Auditoría'), findsOneWidget);
    final row = find.byKey(const Key('audit-1'));
    expect(
      find.descendant(of: row, matching: find.text('Club desactivado')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining('Club Demo · root@example.com'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Como plataforma')),
      findsOneWidget,
    );
  });

  testWidgets('the audit log filters by club', (tester) async {
    platform.audit.addAll([
      AuditEntry(
        id: 1,
        action: 'club_created',
        asPlatformAdmin: true,
        createdAt: DateTime(2026, 11, 8),
        clubId: 'club-idefic',
        clubName: 'IDEFIC',
        actorEmail: 'root@example.com',
        payload: const {'name': 'IDEFIC'},
      ),
      AuditEntry(
        id: 2,
        action: 'club_branding_updated',
        asPlatformAdmin: false,
        createdAt: DateTime(2026, 11, 8, 1),
        clubId: 'club-demo',
        clubName: 'Club Demo',
        actorEmail: 'admin@demo.es',
      ),
    ]);
    await signInAs(tester, 'root@example.com');
    await tester.tap(find.byKey(const Key('open-platform')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-audit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audit-1')), findsOneWidget);
    expect(find.byKey(const Key('audit-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('audit-club-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Club Demo').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audit-1')), findsNothing);
    expect(find.text('Identidad visual cambiada'), findsOneWidget);
  });

  test('audit wording', () {
    expect(auditActionLabel('club_admin_invited'), 'Administrador invitado');
    expect(auditActionLabel('unknown_action'), 'unknown_action');
    expect(formatAuditDate(DateTime(2026, 1, 2, 3, 4)), '02/01/2026 03:04');
  });
}
