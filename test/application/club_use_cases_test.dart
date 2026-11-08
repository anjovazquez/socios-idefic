import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/club/resolve_club_entry.dart';
import 'package:socios_idefic/application/club/select_active_club.dart';

import '../support/fakes.dart';

void main() {
  group('ResolveClubEntry', () {
    late FakeClubRepository clubs;
    late InMemoryActiveClubStore store;
    late ResolveClubEntry resolve;

    setUp(() {
      clubs = FakeClubRepository();
      store = InMemoryActiveClubStore();
      resolve = ResolveClubEntry(clubs, store);
    });

    test('no clubs', () async {
      store.value = 'stale';

      expect(await resolve(), isA<NoClubEntry>());
      expect(store.value, isNull);
    });

    test('a single club is entered directly and remembered', () async {
      clubs.fixed = [idefic];

      final entry = await resolve();

      expect(entry, isA<EnterClubEntry>());
      expect((entry as EnterClubEntry).club.id, idefic.id);
      expect(store.value, idefic.id);
    });

    test('several clubs without a remembered one ask to choose', () async {
      clubs.fixed = [demo, idefic];

      final entry = await resolve();

      expect(entry, isA<ChooseClubEntry>());
      expect(entry.clubs, hasLength(2));
    });

    test('several clubs reopen the remembered one', () async {
      clubs.fixed = [demo, idefic];
      store.value = demo.id;

      final entry = await resolve();

      expect((entry as EnterClubEntry).club.id, demo.id);
    });

    test(
      'a remembered club the user no longer belongs to is ignored',
      () async {
        clubs.fixed = [demo, idefic];
        store.value = 'club-closed';

        expect(await resolve(), isA<ChooseClubEntry>());
      },
    );
  });

  group('SelectActiveClub', () {
    test('remembers the chosen club', () async {
      final store = InMemoryActiveClubStore();

      final club = await SelectActiveClub(store)(demo.id, [idefic, demo]);

      expect(club.name, 'Club Demo');
      expect(store.value, demo.id);
    });

    test('rejects a club outside the user memberships', () {
      expect(
        () => SelectActiveClub(InMemoryActiveClubStore())('other', [idefic]),
        throwsA(isA<UnknownClubFailure>()),
      );
    });
  });
}
