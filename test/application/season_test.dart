import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/season/season_use_cases.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/infrastructure/season/supabase_season_repository.dart';
import 'package:socios_idefic/presentation/format/money.dart';

import '../support/fakes.dart';

Season season(String name, SeasonStatus status, {int? fee}) => Season(
  id: 'season-$name',
  clubId: 'club',
  name: name,
  startsOn: DateTime(int.parse(name.substring(0, 4)), 9),
  endsOn: DateTime(int.parse(name.substring(0, 4)) + 1, 8, 31),
  status: status,
  defaultFeeCents: fee,
);

void main() {
  test('season names are two consecutive years', () {
    expect(isValidSeasonName('2026/2027'), isTrue);
    expect(isValidSeasonName(' 2026/2027 '), isTrue);
    expect(isValidSeasonName('2026/2028'), isFalse);
    expect(isValidSeasonName('2026-2027'), isFalse);
    expect(isValidSeasonName('26/27'), isFalse);
  });

  test('suggests the next season after the newest one', () {
    expect(
      suggestNextSeasonName([
        season('2025/2026', SeasonStatus.closed),
        season('2026/2027', SeasonStatus.active),
      ]),
      '2027/2028',
    );
    expect(
      suggestNextSeasonName([], today: DateTime(2026, 11, 8)),
      '2026/2027',
    );
    expect(suggestNextSeasonName([], today: DateTime(2027, 3, 1)), '2026/2027');
  });

  test('parses amounts typed in euros', () {
    expect(parseEurosToCents('50'), 5000);
    expect(parseEurosToCents('50,5'), 5050);
    expect(parseEurosToCents('50.50'), 5050);
    expect(parseEurosToCents('1.250,00 €'), 125000);
    expect(parseEurosToCents('0'), 0);
    expect(parseEurosToCents(''), isNull);
    expect(parseEurosToCents('-5'), isNull);
    expect(parseEurosToCents('abc'), isNull);
  });

  test('formats cents in euros', () {
    expect(formatCents(5000), '50,00 €');
    expect(formatCents(125050), '1.250,50 €');
    expect(formatCents(0), '0,00 €');
    expect(centsToInput(5000), '50');
    expect(centsToInput(5050), '50,50');
  });

  test('activating requires a fee and a season that is not closed', () {
    final activate = ActivateSeason(FakeSeasonRepository());
    expect(
      () => activate(season: season('2026/2027', SeasonStatus.draft), fee: ''),
      throwsA(
        isA<InvalidSeasonDataFailure>().having(
          (f) => f.field,
          'field',
          SeasonField.fee,
        ),
      ),
    );
    expect(
      () =>
          activate(season: season('2025/2026', SeasonStatus.closed), fee: '50'),
      throwsA(isA<SeasonClosedFailure>()),
    );
  });

  test('creating validates the name', () {
    expect(
      () => CreateSeason(FakeSeasonRepository())(clubId: 'c', name: '2026'),
      throwsA(isA<InvalidSeasonDataFailure>()),
    );
  });

  test('maps rows and errors', () {
    final mapped = seasonFromRow({
      'id': 's1',
      'club_id': 'c1',
      'name': '2026/2027',
      'starts_on': '2026-09-01',
      'ends_on': '2027-08-31',
      'default_fee_cents': 5000,
      'status': 'active',
    });
    expect(mapped.status, SeasonStatus.active);
    expect(mapped.defaultFeeCents, 5000);
    expect(
      mapSeasonError('23505', 'duplicate', null),
      isA<SeasonAlreadyExistsFailure>(),
    );
    expect(
      mapSeasonError('22023', 'season fee required', null),
      isA<InvalidSeasonDataFailure>(),
    );
    expect(
      mapSeasonError('P0001', 'closed', 'season_closed'),
      isA<SeasonClosedFailure>(),
    );
    expect(mapSeasonError('42501', 'x', null), isA<SeasonPermissionFailure>());
  });
}
