import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/member/club_member.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/member/supabase_members_repository.dart';
import 'package:socios_idefic/infrastructure/season/supabase_season_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-013.md — Socio por temporada.
void main() {
  late FakeMembersRepository members;
  late FakeSeasonRepository seasons;

  ClubMember member(String name, int number, {int fee = 5000}) => ClubMember(
    membershipId: 'm-$name',
    email: '${name.toLowerCase()}@example.com',
    firstName: name,
    memberNumber: number,
    isClubAdmin: false,
    status: MemberStatus.active,
    seasonMembershipId: 'sm-$name',
    seasonFeeCents: fee,
    seasonStatus: SeasonMembershipStatus.pendingPayment,
  );

  setUp(() {
    members = FakeMembersRepository(
      members: {
        ideficAsAdmin.id: [
          member('Ana', 2),
          member('Marta', 3),
          member('Luis', 4),
        ],
      },
    );
    seasons = FakeSeasonRepository()
      ..history['m-Ana'] = const [
        MemberSeason(
          seasonName: '2027/2028',
          seasonStatus: SeasonStatus.active,
          status: SeasonMembershipStatus.notRenewed,
        ),
        MemberSeason(
          seasonMembershipId: 'sm-26',
          seasonName: '2026/2027',
          seasonStatus: SeasonStatus.closed,
          status: SeasonMembershipStatus.active,
          feeCents: 5000,
        ),
        MemberSeason(
          seasonMembershipId: 'sm-25',
          seasonName: '2025/2026',
          seasonStatus: SeasonStatus.closed,
          status: SeasonMembershipStatus.active,
          feeCents: 4500,
        ),
      ];
  });

  Future<void> openMembers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository(passwords: {'admin@example.com': 'pw'});
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: auth,
          clubs: FakeClubRepository({
            'admin@example.com': [ideficAsAdmin],
          }),
          members: members,
          seasons: seasons,
        ),
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

  Future<void> setFee(WidgetTester tester, String email, String fee) async {
    await tester.tap(find.byKey(Key('member-$email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-change-fee')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-fee-field')), fee);
    await tester.tap(find.byKey(const Key('member-fee-save')));
    await tester.pumpAndSettle();
  }

  ClubMember find_(String name) =>
      members.members[ideficAsAdmin.id]!.firstWhere((m) => m.firstName == name);

  testWidgets('the list shows the fee of the active season', (tester) async {
    await openMembers(tester);

    expect(
      find.textContaining('50,00 € · Pendiente de pago'),
      findsNWidgets(3),
    );
  });

  testWidgets('custom fees: 25 € and 0 € (exempt)', (tester) async {
    await openMembers(tester);

    await setFee(tester, 'marta@example.com', '25');
    expect(find.text('Cuota de Marta actualizada'), findsOneWidget);
    expect(find_('Marta').seasonFeeCents, 2500);
    expect(find_('Marta').seasonStatus, SeasonMembershipStatus.pendingPayment);

    await setFee(tester, 'luis@example.com', '0');
    expect(find_('Luis').seasonFeeCents, 0);
    expect(find_('Luis').seasonStatus, SeasonMembershipStatus.active);
    expect(find.textContaining('0,00 € · Socio'), findsOneWidget);
  });

  testWidgets('a negative or invalid fee is explained', (tester) async {
    await openMembers(tester);

    await setFee(tester, 'marta@example.com', '-5');

    expect(find.text('Escribe una cuota válida (0 € o más)'), findsOneWidget);
    expect(find_('Marta').seasonFeeCents, 5000);
  });

  testWidgets('the record shows the history per season', (tester) async {
    await openMembers(tester);

    await tester.tap(find.byKey(const Key('member-ana@example.com')));
    await tester.pumpAndSettle();

    final history = find.byKey(const Key('member-history'));
    expect(
      find.descendant(of: history, matching: find.text('No renovado')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: history, matching: find.text('Socio')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: history, matching: find.text('45,00 €')),
      findsOneWidget,
    );
  });

  test('maps the season columns and the history rows', () {
    final mapped = clubMemberFromRow({
      'membership_id': 'm1',
      'email': 'a@b.es',
      'role': 'member',
      'status': 'active',
      'season_membership_id': 'sm1',
      'season_fee_cents': 2500,
      'season_status': 'pending_payment',
    });
    expect(mapped.seasonFeeCents, 2500);
    expect(mapped.seasonStatus, SeasonMembershipStatus.pendingPayment);

    final row = memberSeasonFromRow({
      'season_membership_id': null,
      'season_name': '2027/2028',
      'season_status': 'active',
      'fee_cents': null,
      'status': 'not_renewed',
    });
    expect(row.status, SeasonMembershipStatus.notRenewed);
    expect(row.seasonMembershipId, isNull);
  });
}
