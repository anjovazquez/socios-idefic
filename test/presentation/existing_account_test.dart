import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/club/my_club.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-008.md — Usuario en varios clubes.
void main() {
  const demoAsAdmin = MyClub(
    id: 'club-demo',
    name: 'Club Demo',
    code: 'DEMO',
    role: ClubRole.clubAdmin,
    primaryColor: '#B3261E',
    memberNumber: 1,
  );

  testWidgets('an existing account joins another club with the same '
      'credentials and without a new first access', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository(
      passwords: {'admin.demo@example.com': 'pw', 'usuario@example.com': 'pw'},
    );
    final clubs = FakeClubRepository({
      'admin.demo@example.com': [demoAsAdmin],
      'usuario@example.com': [idefic],
    });
    final members = FakeMembersRepository()
      ..existingAccounts = {'usuario@example.com'};
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs, members: members),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> signIn(String email) async {
      await tester.enterText(find.byKey(const Key('login-email')), email);
      await tester.enterText(find.byKey(const Key('login-password')), 'pw');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
    }

    // Admin of Club Demo signs up the existing account, with capitals.
    await signIn('admin.demo@example.com');
    await tester.tap(find.byKey(const Key('open-members')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-member')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('new-member-name')), 'Usuario');
    await tester.enterText(
      find.byKey(const Key('new-member-email')),
      'Usuario@Example.com',
    );
    await tester.tap(find.byKey(const Key('new-member-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('ya tenía cuenta'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    // The member signs in as always and now chooses between both clubs.
    await signIn('usuario@example.com');
    expect(find.text('Elige tu club'), findsOneWidget);
    expect(find.byKey(const Key('club-IDEFIC')), findsOneWidget);
    expect(find.byKey(const Key('club-DEMO')), findsOneWidget);
    expect(find.text('Activa tu cuenta'), findsNothing);
  });
}
