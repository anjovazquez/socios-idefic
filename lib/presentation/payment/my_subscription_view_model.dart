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
      ]);
      _subscription = results[0] as MySubscription;
      _payments = results[1] as List<MyPayment>;
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
