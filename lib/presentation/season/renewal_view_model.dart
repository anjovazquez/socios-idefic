import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/season/renewal.dart';
import '../../domain/season/season.dart';
import 'seasons_view_model.dart';

/// Bulk renewal into one season (RF-009): who and for how much.
class RenewalViewModel extends ChangeNotifier {
  RenewalViewModel(this._useCases, {required this.seasonId});

  final AppUseCases _useCases;
  final String seasonId;

  List<RenewalCandidate> _candidates = const [];
  List<RenewalCandidate> get candidates => _candidates;

  bool _keepCustomFees = true;
  bool get keepCustomFees => _keepCustomFees;

  final Set<String> _excluded = {};
  final Map<String, int> _fees = {};

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRenewing = false;
  bool get isRenewing => _isRenewing;

  String? _error;
  String? get error => _error;

  String? get previousSeasonName =>
      _candidates.isEmpty ? null : _candidates.first.previousSeasonName;

  Iterable<RenewalCandidate> get _pending =>
      _candidates.where((c) => !c.alreadyRenewed);

  bool isSelected(RenewalCandidate c) =>
      !c.alreadyRenewed && !_excluded.contains(c.membershipId);

  int feeOf(RenewalCandidate c) => _fees[c.membershipId] ?? c.proposedFeeCents;

  int get selectedCount => _pending.where(isSelected).length;
  int get excludedCount => _pending.length - selectedCount;
  int get alreadyRenewedCount => _candidates.length - _pending.length;
  int get totalCents =>
      _pending.where(isSelected).fold(0, (s, c) => s + feeOf(c));

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _candidates = await _useCases.getRenewalCandidates(
        seasonId,
        keepCustomFees: _keepCustomFees,
      );
    } on SeasonFailure catch (failure) {
      _error = SeasonsViewModel.messageFor(failure);
    } catch (_) {
      _error = SeasonsViewModel.messageFor(const SeasonUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reloads the proposal; manual fee changes are discarded.
  Future<void> setKeepCustomFees(bool value) {
    _keepCustomFees = value;
    _fees.clear();
    return load();
  }

  void toggle(RenewalCandidate c) {
    if (c.alreadyRenewed) return;
    if (!_excluded.remove(c.membershipId)) _excluded.add(c.membershipId);
    notifyListeners();
  }

  void selectAll(bool selected) {
    selected
        ? _excluded.clear()
        : _excluded.addAll(_pending.map((c) => c.membershipId));
    notifyListeners();
  }

  /// Returns the confirmation, or throws the message when [fee] is invalid.
  Future<String> setFee(RenewalCandidate c, String fee) async {
    final cents = parseEurosToCents(fee);
    if (cents == null) throw 'Escribe una cuota válida (0 € o más)';
    _fees[c.membershipId] = cents;
    notifyListeners();
    return 'Cuota de ${c.displayName} para la renovación cambiada';
  }

  /// Returns the confirmation, or throws the error message.
  Future<String> renew() async {
    _isRenewing = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _useCases.bulkRenew(seasonId, [
        for (final c in _pending.where(isSelected))
          RenewalItem(membershipId: c.membershipId, feeCents: feeOf(c)),
      ]);
      _excluded.clear();
      _fees.clear();
      await load();
      return created == 1 ? '1 socio renovado' : '$created socios renovados';
    } on SeasonFailure catch (failure) {
      throw SeasonsViewModel.messageFor(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw SeasonsViewModel.messageFor(const SeasonUnavailableFailure());
    } finally {
      _isRenewing = false;
      notifyListeners();
    }
  }
}
