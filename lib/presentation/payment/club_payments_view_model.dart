import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/payment/club_payments.dart';
import '../../domain/payment/payment.dart';
import '../../domain/season/season.dart';
import 'payment_labels.dart';

/// Payments of the club for its admin (RF-018, §16 Pagos).
class ClubPaymentsViewModel extends ChangeNotifier {
  ClubPaymentsViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  List<Season> _seasons = const [];
  List<Season> get seasons => _seasons;

  ClubPaymentsFilter _filter = const ClubPaymentsFilter();
  ClubPaymentsFilter get filter => _filter;

  ClubPaymentsPage _page = ClubPaymentsPage.empty;
  List<ClubPaymentLine> get lines => _page.lines;
  int get total => _page.total;
  int get paidCents => _page.paidCents;
  int get pendingCents => _page.pendingCents;
  bool get hasMore => lines.length < total;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  String? _downloadingId;
  String? get downloadingId => _downloadingId;

  /// Ignores answers of searches that were replaced while loading.
  int _request = 0;

  /// Starts on the active season, if there is one.
  Future<void> load() async {
    try {
      _seasons = await _useCases.getSeasons(clubId);
    } catch (_) {
      _seasons = const [];
    }
    final active = _seasons
        .where((s) => s.status == SeasonStatus.active)
        .firstOrNull;
    _filter = ClubPaymentsFilter(seasonId: active?.id);
    await _fetch(reset: true);
  }

  Future<void> selectSeason(String? seasonId) => _apply(
    ClubPaymentsFilter(
      seasonId: seasonId,
      query: _filter.query,
      status: _filter.status,
    ),
  );

  Future<void> search(String query) => _apply(
    ClubPaymentsFilter(
      seasonId: _filter.seasonId,
      query: query,
      status: _filter.status,
    ),
  );

  Future<void> selectStatus(PaymentStatus? status) => _apply(
    ClubPaymentsFilter(
      seasonId: _filter.seasonId,
      query: _filter.query,
      status: status,
    ),
  );

  Future<void> loadMore() =>
      hasMore && !_isLoading ? _fetch(reset: false) : Future.value();

  Future<void> _apply(ClubPaymentsFilter filter) {
    _filter = filter;
    return _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    final request = ++_request;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final page = await _useCases.getClubPayments(
        clubId,
        filter: _filter,
        offset: reset ? 0 : lines.length,
      );
      if (request != _request) return;
      _page = reset
          ? page
          : ClubPaymentsPage(
              lines: [...lines, ...page.lines],
              total: page.total,
              paidCents: page.paidCents,
              pendingCents: page.pendingCents,
            );
    } on PaymentFailure catch (failure) {
      if (request == _request) _loadError = paymentFailureMessage(failure);
    } catch (_) {
      if (request == _request) {
        _loadError = paymentFailureMessage(const PaymentUnavailableFailure());
      }
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Returns the confirmation, or throws the error message.
  Future<String> downloadReceipt(ClubPaymentLine line) async {
    _downloadingId = line.id;
    notifyListeners();
    try {
      final receipt = await _useCases.downloadReceipt(line.paymentId!);
      return 'Recibo ${receipt.code} listo';
    } on PaymentFailure catch (failure) {
      throw paymentFailureMessage(failure);
    } catch (_) {
      throw 'No hemos podido preparar el recibo. Inténtalo de nuevo en un '
          'momento';
    } finally {
      _downloadingId = null;
      notifyListeners();
    }
  }
}
