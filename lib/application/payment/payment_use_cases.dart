import '../../domain/payment/club_payments.dart';
import '../../domain/payment/my_subscription.dart';
import '../../domain/payment/online_payments.dart';
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
    bool saveForRenewal = false,
  }) => _gateway.start(
    clubId: clubId,
    seasonMembershipId: seasonMembershipId,
    saveForRenewal: saveForRenewal,
  );
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

class GetClubPayments {
  const GetClubPayments(this._repository);

  final PaymentsRepository _repository;

  Future<ClubPaymentsPage> call(
    String clubId, {
    ClubPaymentsFilter filter = const ClubPaymentsFilter(),
    int offset = 0,
  }) => _repository.getClubPayments(clubId, filter: filter, offset: offset);
}

class GetOnlinePaymentsStatus {
  const GetOnlinePaymentsStatus(this._repository);

  final PaymentsRepository _repository;

  Future<OnlinePaymentsStatus> call(String clubId) =>
      _repository.getOnlinePaymentsStatus(clubId);
}

class StartOnlinePaymentsOnboarding {
  const StartOnlinePaymentsOnboarding(this._repository);

  final PaymentsRepository _repository;

  Future<Uri> call(String clubId) =>
      _repository.startOnlinePaymentsOnboarding(clubId);
}

class RefreshOnlinePaymentsStatus {
  const RefreshOnlinePaymentsStatus(this._repository);

  final PaymentsRepository _repository;

  Future<OnlinePaymentsStatus> call(String clubId) =>
      _repository.refreshOnlinePaymentsStatus(clubId);
}

class GetMyRenewalSetup {
  const GetMyRenewalSetup(this._repository);

  final PaymentsRepository _repository;

  Future<RenewalSetup> call(String clubId) =>
      _repository.getMyRenewalSetup(clubId);
}

class StartPaymentMethodSetup {
  const StartPaymentMethodSetup(this._repository);

  final PaymentsRepository _repository;

  Future<Uri> call(String clubId) =>
      _repository.startPaymentMethodSetup(clubId);
}

class RemovePaymentMethod {
  const RemovePaymentMethod(this._repository);

  final PaymentsRepository _repository;

  Future<void> call(String clubId) => _repository.removePaymentMethod(clubId);
}

class CancelRenewal {
  const CancelRenewal(this._repository);

  final PaymentsRepository _repository;

  Future<void> call(String seasonMembershipId) =>
      _repository.cancelRenewal(seasonMembershipId);
}
