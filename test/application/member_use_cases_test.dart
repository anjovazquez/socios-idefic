import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/member/member_use_cases.dart';
import 'package:socios_idefic/domain/member/club_member.dart';
import 'package:socios_idefic/infrastructure/member/supabase_members_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeMembersRepository repository;

  setUp(() async {
    final auth = FakeAuthRepository(passwords: {'admin@example.com': 'pw'});
    await auth.signInWithPassword(email: 'admin@example.com', password: 'pw');
    repository = FakeMembersRepository(auth: auth)
      ..clubs = (FakeClubRepository({
        'admin@example.com': [ideficAsAdmin],
      })..auth = auth);
  });

  test('InviteMember normalizes before calling the server', () async {
    await InviteMember(repository)(
      clubId: ideficAsAdmin.id,
      email: '  Marta@Example.COM ',
      firstName: ' Marta ',
    );

    final member = repository.members[ideficAsAdmin.id]!.single;
    expect(member.email, 'marta@example.com');
    expect(member.firstName, 'Marta');
    expect(member.status, MemberStatus.invited);
  });

  for (final (label, name, email, field) in [
    ('empty name', ' ', 'a@b.es', MemberField.name),
    ('missing email', 'Ana', '', MemberField.email),
    ('invalid email', 'Ana', 'ana@', MemberField.email),
  ]) {
    test('InviteMember rejects $label', () {
      expect(
        () => InviteMember(repository)(
          clubId: ideficAsAdmin.id,
          email: email,
          firstName: name,
        ),
        throwsA(
          isA<InvalidMemberDataFailure>().having(
            (f) => f.field,
            'field',
            field,
          ),
        ),
      );
      expect(repository.sentEmails, isEmpty);
    });
  }

  test('maps a get_club_members row', () {
    final member = clubMemberFromRow({
      'membership_id': 'm1',
      'user_id': 'u1',
      'email': 'marta@example.com',
      'first_name': 'Marta',
      'last_name': null,
      'member_number': 4,
      'role': 'member',
      'status': 'invited',
      'invited_at': '2026-11-08T12:00:00+00:00',
    });

    expect(member.status, MemberStatus.invited);
    expect(member.memberNumber, 4);
    expect(member.displayName, 'Marta');
    expect(member.invitedAt, isNotNull);
  });

  test('maps function errors', () {
    expect(
      mapInvitationError(400, 'invalid_email'),
      isA<InvalidMemberDataFailure>(),
    );
    expect(
      mapInvitationError(409, 'already_member'),
      isA<AlreadyMemberFailure>(),
    );
    expect(
      mapInvitationError(409, 'not_pending'),
      isA<InvitationNotPendingFailure>(),
    );
    expect(
      mapInvitationError(403, 'forbidden'),
      isA<MemberPermissionFailure>(),
    );
    expect(mapInvitationError(401, null), isA<MemberPermissionFailure>());
    expect(
      mapInvitationError(500, 'unavailable'),
      isA<MemberUnavailableFailure>(),
    );
  });
}
