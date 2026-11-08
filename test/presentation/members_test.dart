import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/member/club_member.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-006.md — Alta de socio.
void main() {
  late FakeAuthRepository auth;
  late FakeClubRepository clubs;
  late FakeMembersRepository members;

  setUp(() {
    auth = FakeAuthRepository(
      passwords: {'admin@example.com': 'pw', 'ana@example.com': 'pw'},
    );
    clubs = FakeClubRepository({
      'admin@example.com': [ideficAsAdmin],
      'ana@example.com': [idefic],
    });
    members = FakeMembersRepository(
      members: {
        ideficAsAdmin.id: [
          const ClubMember(
            membershipId: 'm-admin',
            email: 'admin@example.com',
            firstName: 'Admin',
            memberNumber: 1,
            isClubAdmin: true,
            status: MemberStatus.active,
          ),
          const ClubMember(
            membershipId: 'm-ana',
            email: 'ana@example.com',
            firstName: 'Ana',
            memberNumber: 2,
            isClubAdmin: false,
            status: MemberStatus.active,
          ),
        ],
      },
    )..existingAccounts = {'luis@example.com'};
  });

  Future<void> openMembersAs(WidgetTester tester, String email) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs, members: members),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('open-members')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('open-members')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> signUp(WidgetTester tester, String name, String email) async {
    await tester.tap(find.byKey(const Key('new-member')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('new-member-name')), name);
    await tester.enterText(find.byKey(const Key('new-member-email')), email);
    await tester.tap(find.byKey(const Key('new-member-save')));
    await tester.pumpAndSettle();
  }

  Finder inRow(String email, Finder matching) =>
      find.descendant(of: find.byKey(Key('member-$email')), matching: matching);

  testWidgets('the admin signs up a member who appears as invited', (
    tester,
  ) async {
    await openMembersAs(tester, 'admin@example.com');
    expect(find.text('Socios'), findsOneWidget);

    await signUp(tester, 'Marta', 'marta@example.com');

    expect(find.text('Invitación enviada a marta@example.com'), findsOneWidget);
    expect(inRow('marta@example.com', find.text('Invitado')), findsOneWidget);
    expect(inRow('marta@example.com', find.text('3')), findsOneWidget);
    expect(members.sentEmails, ['marta@example.com']);
  });

  testWidgets('email is required and must be valid', (tester) async {
    await openMembersAs(tester, 'admin@example.com');

    await signUp(tester, 'Marta', 'marta@');

    expect(find.text('Escribe un email válido'), findsOneWidget);
    expect(find.byKey(const Key('new-member-save')), findsOneWidget);
    expect(members.sentEmails, isEmpty);
  });

  testWidgets('an existing member cannot be signed up twice', (tester) async {
    await openMembersAs(tester, 'admin@example.com');

    await signUp(tester, 'Ana', 'ana@example.com');

    expect(find.text('Esta persona ya es socia del club'), findsOneWidget);
  });

  testWidgets('an email with an account joins directly', (tester) async {
    await openMembersAs(tester, 'admin@example.com');

    await signUp(tester, 'Luis', 'luis@example.com');

    expect(
      find.text(
        'luis@example.com ya tenía cuenta: ahora también es socio del club',
      ),
      findsOneWidget,
    );
    expect(inRow('luis@example.com', find.text('Activo')), findsOneWidget);
  });

  testWidgets('the admin resends a pending invitation', (tester) async {
    await openMembersAs(tester, 'admin@example.com');
    await signUp(tester, 'Marta', 'marta@example.com');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.byKey(const Key('resend-marta@example.com')));
    await tester.pumpAndSettle();

    expect(
      find.text('Nueva invitación enviada a marta@example.com'),
      findsOneWidget,
    );
    expect(members.sentEmails, ['marta@example.com', 'marta@example.com']);
    expect(find.byKey(const Key('resend-ana@example.com')), findsNothing);
  });

  testWidgets('a member cannot sign up others', (tester) async {
    await openMembersAs(tester, 'ana@example.com');

    expect(find.byKey(const Key('open-members')), findsNothing);
    expect(find.byKey(const Key('new-member')), findsNothing);
  });
}
