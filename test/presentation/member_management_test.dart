import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/member/club_member.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-011.md — Gestión de socios.
void main() {
  late FakeMembersRepository members;
  late FakeClubRepository clubs;

  ClubMember member(int number, String name, {MemberStatus? status}) =>
      ClubMember(
        membershipId: 'm$number',
        email: '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
        firstName: name,
        memberNumber: number,
        isClubAdmin: number == 1,
        status: status ?? MemberStatus.active,
        phone: '600000${number.toString().padLeft(3, '0')}',
      );

  setUp(() {
    clubs = FakeClubRepository({
      'admin@example.com': [ideficAsAdmin],
      'marta@example.com': [idefic],
    });
    members = FakeMembersRepository(
      members: {
        ideficAsAdmin.id: [
          member(1, 'Admin'),
          member(2, 'Marta'),
          member(3, 'Martín'),
          member(4, 'Pedro', status: MemberStatus.invited),
          member(5, 'Lucía', status: MemberStatus.inactive),
          for (var i = 6; i <= 60; i++) member(i, 'Socio $i'),
        ],
      },
    );
  });

  Future<void> openMembers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository(passwords: {'admin@example.com': 'pw'});
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs, members: members),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'admin@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-members')));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('members-search')), text);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('search by name', (tester) async {
    await openMembers(tester);
    expect(find.text('60 socios'), findsOneWidget);

    await search(tester, 'mart');

    expect(find.text('2 socios'), findsOneWidget);
    expect(find.byKey(const Key('member-marta@example.com')), findsOneWidget);
    expect(find.byKey(const Key('member-martín@example.com')), findsOneWidget);
    expect(find.byKey(const Key('member-pedro@example.com')), findsNothing);
  });

  testWidgets('filter by status and page through the list', (tester) async {
    await openMembers(tester);
    final list = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('members-more')),
      400,
      scrollable: list.first,
    );
    expect(
      find.byKey(const Key('member-socio.50@example.com')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('members-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('member-socio.60@example.com')),
      400,
      scrollable: list.first,
    );
    expect(find.byKey(const Key('members-more')), findsNothing);

    await tester.tap(find.byKey(const Key('members-filter-invited')));
    await tester.pumpAndSettle();
    expect(find.text('1 socio'), findsOneWidget);
    expect(find.byKey(const Key('member-pedro@example.com')), findsOneWidget);
  });

  testWidgets('deactivate and reactivate a member', (tester) async {
    await openMembers(tester);
    await search(tester, 'marta');

    await tester.tap(find.byKey(const Key('member-marta@example.com')));
    await tester.pumpAndSettle();
    expect(find.text('600000002'), findsOneWidget);
    await tester.tap(find.byKey(const Key('member-deactivate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-deactivate-member')));
    await tester.pumpAndSettle();

    expect(find.text('Marta ha causado baja en el club'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('member-marta@example.com')),
        matching: find.text('Baja'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('member-marta@example.com')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-reactivate')));
    await tester.pumpAndSettle();

    expect(find.text('Marta vuelve a ser socio del club'), findsOneWidget);
    final marta = members.members[ideficAsAdmin.id]!.firstWhere(
      (m) => m.firstName == 'Marta',
    );
    expect(marta.status, MemberStatus.active);
    expect(marta.memberNumber, 2);
  });

  testWidgets('the club admin cannot be deactivated', (tester) async {
    await openMembers(tester);
    await search(tester, 'admin');

    await tester.tap(find.byKey(const Key('member-admin@example.com')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('member-deactivate')), findsNothing);
    expect(find.text('Es el administrador del club'), findsOneWidget);
  });

  testWidgets('an empty search explains it', (tester) async {
    await openMembers(tester);

    await search(tester, 'zzz');

    expect(find.text('Ningún socio coincide con la búsqueda'), findsOneWidget);
  });
}
