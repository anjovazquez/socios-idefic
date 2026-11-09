import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/club/my_club.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';
import '../support/navigation.dart';

// BDD: tasks/VS-012.md — Temporadas.
void main() {
  late FakeClubRepository clubs;
  late FakeSeasonRepository seasons;

  setUp(() {
    const adminClub = MyClub(
      id: 'club-idefic',
      name: 'IDEFIC',
      code: 'IDEFIC',
      role: ClubRole.clubAdmin,
      memberNumber: 1,
      activeSeasonName: '2026/2027',
    );
    const memberClub = MyClub(
      id: 'club-idefic',
      name: 'IDEFIC',
      code: 'IDEFIC',
      role: ClubRole.member,
      memberNumber: 2,
      activeSeasonName: '2026/2027',
    );
    clubs = FakeClubRepository({
      'admin@example.com': [adminClub],
      'ana@example.com': [memberClub],
    });
    seasons = FakeSeasonRepository({
      'club-idefic': [
        Season(
          id: 'season-2026/2027',
          clubId: 'club-idefic',
          name: '2026/2027',
          startsOn: DateTime(2026, 9),
          endsOn: DateTime(2027, 8, 31),
          status: SeasonStatus.active,
          defaultFeeCents: 5000,
        ),
      ],
    });
  });

  Future<void> signInAs(WidgetTester tester, String email) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository(passwords: {email: 'pw'});
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs, seasons: seasons),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  Future<void> createSeason(WidgetTester tester, {String? name}) async {
    await tester.tap(find.byKey(const Key('new-season')));
    await tester.pumpAndSettle();
    if (name != null) {
      await tester.enterText(find.byKey(const Key('new-season-name')), name);
    }
    await tester.tap(find.byKey(const Key('new-season-save')));
    await tester.pumpAndSettle();
  }

  Future<void> activate(WidgetTester tester, String name, String fee) async {
    await tester.tap(find.byKey(Key('season-action-$name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activate-season-fee')), fee);
    await tester.tap(find.byKey(const Key('activate-season-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('create and activate the next season', (tester) async {
    await signInAs(tester, 'admin@example.com');
    expect(find.text('Temporada 2026/2027'), findsOneWidget);
    await openAdminSection(tester, 'open-seasons');
    await tester.pumpAndSettle();

    await createSeason(tester);
    expect(find.text('Temporada 2027/2028 creada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('season-action-2027/2028')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('2026/2027 dejará de ser la temporada activa'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('activate-season-fee')), '50');
    await tester.tap(find.byKey(const Key('activate-season-save')));
    await tester.pumpAndSettle();

    expect(find.text('Temporada 2027/2028 activa'), findsOneWidget);
    final active = find.byKey(const Key('season-2027/2028'));
    expect(
      find.descendant(of: active, matching: find.text('Activa')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: active, matching: find.text('Cuota: 50,00 €')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('season-2026/2027')),
        matching: find.text('Cerrada'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Temporada 2027/2028'), findsOneWidget);
  });

  testWidgets('the fee is required', (tester) async {
    await signInAs(tester, 'admin@example.com');
    await openAdminSection(tester, 'open-seasons');
    await tester.pumpAndSettle();
    await createSeason(tester);

    await activate(tester, '2027/2028', '');

    expect(find.text('Indica la cuota de la temporada'), findsOneWidget);
  });

  testWidgets('duplicate names are rejected', (tester) async {
    await signInAs(tester, 'admin@example.com');
    await openAdminSection(tester, 'open-seasons');
    await tester.pumpAndSettle();

    await createSeason(tester, name: '2026/2027');

    expect(find.text('Ya existe una temporada con ese nombre'), findsOneWidget);
  });

  testWidgets('members see the active season but cannot manage seasons', (
    tester,
  ) async {
    await signInAs(tester, 'ana@example.com');

    expect(find.text('Temporada 2026/2027'), findsOneWidget);
    expect(find.byKey(const Key('open-admin-menu')), findsNothing);
  });
}
