import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/payment/my_subscription.dart';
import '../../domain/payment/payment.dart';
import '../../domain/payment/payment_gateway.dart';
import 'payment_labels.dart';

/// «Mi suscripción»: current season and payment history (RF-011, RF-016).
class MySubscriptionViewModel extends ChangeNotifier {
  MySubscriptionViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  MySubscription? _subscription;
  MySubscription? get subscription => _subscription;

  List<MyPayment> _payments = const [];
  List<MyPayment> get payments => _payments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _useCases.getMySubscription(clubId),
        _useCases.getMyPayments(clubId),
        _useCases
            .getMyRenewalSetup(clubId)
            .catchError((_) => RenewalSetup.none),
      ]);
      _subscription = results[0] as MySubscription;
      _payments = results[1] as List<MyPayment>;
      _renewal = results[2] as RenewalSetup;
    } catch (_) {
      _loadError =
          'No hemos podido cargar tu suscripción. Inténtalo de nuevo en un '
          'momento';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _downloadingId;

  /// Payment whose receipt is being prepared, to show progress.
  String? get downloadingId => _downloadingId;

  /// Returns the confirmation, or throws the error message.
  Future<String> downloadReceipt(MyPayment payment) async {
    _downloadingId = payment.id;
    notifyListeners();
    try {
      final receipt = await _useCases.downloadReceipt(payment.id);
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

  RenewalSetup _renewal = RenewalSetup.none;
  RenewalSetup get renewal => _renewal;

  /// «Usar este método para renovar automáticamente» (explicit opt-in).
  bool _saveForRenewal = false;
  bool get saveForRenewal => _saveForRenewal;

  void setSaveForRenewal(bool value) {
    _saveForRenewal = value;
    notifyListeners();
  }

  bool _changingMethod = false;
  bool get changingMethod => _changingMethod;

  /// Returns the provider page to save a method, or throws the message.
  Future<Uri> setUpMethod() =>
      _method(() => _useCases.startPaymentMethodSetup(clubId));

  /// Returns the confirmation, or throws the error message.
  Future<String> removeMethod() async {
    await _method(() => _useCases.removePaymentMethod(clubId));
    _renewal = RenewalSetup.none;
    notifyListeners();
    return 'Método eliminado. La renovación automática está desactivada';
  }

  Future<T> _method<T>(Future<T> Function() action) async {
    _changingMethod = true;
    notifyListeners();
    try {
      return await action();
    } on PaymentFailure catch (failure) {
      throw paymentFailureMessage(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw paymentFailureMessage(const PaymentUnavailableFailure());
    } finally {
      _changingMethod = false;
      notifyListeners();
    }
  }

  bool _startingPayment = false;
  bool get startingPayment => _startingPayment;

  /// Returns the provider checkout page, or throws the error message.
  Future<Uri> payOnline() async {
    final seasonMembershipId = _subscription?.seasonMembershipId;
    if (seasonMembershipId == null) {
      throw paymentFailureMessage(const NotPayableFailure());
    }
    _startingPayment = true;
    notifyListeners();
    try {
      final start = await _useCases.startOnlinePayment(
        clubId: clubId,
        seasonMembershipId: seasonMembershipId,
        saveForRenewal: _saveForRenewal,
      );
      return switch (start) {
        RedirectPaymentStart(:final url) => url,
        ManualPaymentStart() => throw paymentFailureMessage(
          const OnlinePaymentsUnavailableFailure(),
        ),
      };
    } on PaymentFailure catch (failure) {
      throw paymentFailureMessage(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw paymentFailureMessage(const PaymentUnavailableFailure());
    } finally {
      _startingPayment = false;
      notifyListeners();
    }
  }
}
