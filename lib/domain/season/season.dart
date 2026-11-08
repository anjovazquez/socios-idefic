enum SeasonStatus { draft, active, closed }

/// A season of a club with its ordinary fee (RF-007, RF-008).
class Season {
  const Season({
    required this.id,
    required this.clubId,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.status,
    this.defaultFeeCents,
  });

  final String id;
  final String clubId;

  /// `YYYY/YYYY` with consecutive years, e.g. `2026/2027`.
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final SeasonStatus status;

  /// Ordinary fee in euro cents; set when the season is activated.
  final int? defaultFeeCents;
}

final _seasonName = RegExp(r'^(\d{4})/(\d{4})$');

bool isValidSeasonName(String name) {
  final match = _seasonName.firstMatch(name.trim());
  return match != null &&
      int.parse(match.group(2)!) == int.parse(match.group(1)!) + 1;
}

/// Next name after the newest season, or the current one when there is none
/// (seasons start in September).
String suggestNextSeasonName(List<Season> seasons, {DateTime? today}) {
  final years = seasons
      .map((s) => _seasonName.firstMatch(s.name))
      .whereType<RegExpMatch>()
      .map((m) => int.parse(m.group(1)!));
  final now = today ?? DateTime.now();
  final first = years.isEmpty
      ? (now.month >= 9 ? now.year : now.year - 1)
      : years.reduce((a, b) => a > b ? a : b) + 1;
  return '$first/${first + 1}';
}

/// Parses an amount typed in euros ("50", "50,5", "50.50", "1.250,00").
/// Returns null when it is not a valid non-negative amount.
int? parseEurosToCents(String input) {
  var text = input.trim().replaceAll('€', '').replaceAll(' ', '');
  if (text.isEmpty) return null;
  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  }
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final euros = int.parse(match.group(1)!);
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  return euros * 100 + int.parse(decimals.isEmpty ? '0' : decimals);
}

enum SeasonField { name, dates, fee }

sealed class SeasonFailure implements Exception {
  const SeasonFailure();
}

final class InvalidSeasonDataFailure extends SeasonFailure {
  const InvalidSeasonDataFailure(this.field);

  final SeasonField field;
}

final class SeasonAlreadyExistsFailure extends SeasonFailure {
  const SeasonAlreadyExistsFailure();
}

final class SeasonClosedFailure extends SeasonFailure {
  const SeasonClosedFailure();
}

final class SeasonPermissionFailure extends SeasonFailure {
  const SeasonPermissionFailure();
}

final class SeasonUnavailableFailure extends SeasonFailure {
  const SeasonUnavailableFailure([this.cause]);

  final Object? cause;
}
