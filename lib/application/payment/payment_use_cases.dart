import '../../domain/payment/my_subscription.dart';
import '../../domain/payment/payment.dart';
import '../../domain/payment/payment_gateway.dart';
import '../../domain/payment/payments_repository.dart';
import '../../domain/payment/receipt.dart';
import '../../domain/season/season.dart';

class GetSeasonPayments {
  const GetSeasonPayments(this._repository);

  final PaymentsRepository _repository;

  Future<List<Payment>> call(String seasonMembershipId) =>
      _repository.getSeasonPayments(seasonMembershipId);
}

class RecordManualPayment {
  const RecordManualPayment(this._repository);

  final PaymentsRepository _repository;

  /// [amount] in euros as typed; empty = the member's fee.
  Future<void> call({
    required String seasonMembershipId,
    required PaymentMethod method,
    String amount = '',
    DateTime? paidOn,
    String? reference,
  }) {
    if (!manualPaymentMethods.contains(method)) {
      throw const PaymentUnavailableFailure('not a manual method');
    }
    int? cents;
    if (amount.trim().isNotEmpty) {
      cents = parseEurosToCents(amount);
      if (cents == null || cents <= 0) {
        throw const InvalidPaymentAmountFailure();
      }
    }
    return _repository.recordManualPayment(
      seasonMembershipId: seasonMembershipId,
      method: method,
      amountCents: cents,
      paidOn: paidOn,
      reference: reference,
    );
  }
}

class CancelPayment {
  const CancelPayment(this._repository);

  final PaymentsRepository _repository;

  Future<void> call(Payment payment) {
    if (!payment.canBeCancelled) {
      throw const InvalidPaymentTransitionFailure();
    }
    return _repository.setStatus(payment.id, PaymentStatus.cancelled);
  }
}

class GetPaymentInstructions {
  const GetPaymentInstructions(this._repository);

  final PaymentsRepository _repository;

  Future<String?> call(String clubId) =>
      _repository.getPaymentInstructions(clubId);
}

class SetPaymentInstructions {
  const SetPaymentInstructions(this._repository);

  final PaymentsRepository _repository;

  Future<void> call(String clubId, String instructions) =>
      _repository.setPaymentInstructions(clubId, instructions);
}

class StartPayment {
  const StartPayment(this._gateway);

  final PaymentGateway _gateway;

  Future<PaymentStart> call({
    required String clubId,
    required String seasonMembershipId,
  }) => _gateway.start(clubId: clubId, seasonMembershipId: seasonMembershipId);
}

class GetMySubscription {
  const GetMySubscription(this._repository);

  final PaymentsRepository _repository;

  Future<MySubscription> call(String clubId) =>
      _repository.getMySubscription(clubId);
}

class GetMyPayments {
  const GetMyPayments(this._repository);

  final PaymentsRepository _repository;

  Future<List<MyPayment>> call(String clubId) =>
      _repository.getMyPayments(clubId);
}

class DownloadReceipt {
  const DownloadReceipt(this._repository, this._renderer);

  final PaymentsRepository _repository;
  final ReceiptRenderer _renderer;

  Future<Receipt> call(String paymentId) async {
    final receipt = await _repository.getReceipt(paymentId);
    await _renderer.deliver(receipt);
    return receipt;
  }
}
