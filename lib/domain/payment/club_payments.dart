import 'payment.dart';

/// One line of the club payments for the admin (RF-018). A fee still pending
/// without any payment has no [paymentId].
class ClubPaymentLine {
  const ClubPaymentLine({
    required this.seasonMembershipId,
    required this.seasonId,
    required this.seasonName,
    required this.memberName,
    required this.memberEmail,
    required this.concept,
    required this.amountCents,
    required this.status,
    this.paymentId,
    this.memberNumber,
    this.date,
    this.provider,
    this.method,
    this.receiptNumber,
  });

  final String? paymentId;
  final String seasonMembershipId;
  final String seasonId;
  final String seasonName;
  final String memberName;
  final String memberEmail;
  final int? memberNumber;
  final String concept;
  final int amountCents;
  final DateTime? date;
  final PaymentStatus status;
  final PaymentProvider? provider;
  final PaymentMethod? method;
  final int? receiptNumber;

  bool get hasReceipt =>
      paymentId != null &&
      status == PaymentStatus.paid &&
      receiptNumber != null;

  /// Stable key for lists (pending fees have no payment id).
  String get id => paymentId ?? 'fee-$seasonMembershipId';
}

class ClubPaymentsPage {
  const ClubPaymentsPage({
    required this.lines,
    required this.total,
    required this.paidCents,
    required this.pendingCents,
  });

  static const empty = ClubPaymentsPage(
    lines: [],
    total: 0,
    paidCents: 0,
    pendingCents: 0,
  );

  final List<ClubPaymentLine> lines;

  /// Lines matching the filters (all pages).
  final int total;

  /// Collected and pending amounts of the filtered lines (all pages).
  final int paidCents;
  final int pendingCents;
}

/// Filters of the club payments (RF-018: season, member, status).
class ClubPaymentsFilter {
  const ClubPaymentsFilter({this.seasonId, this.query = '', this.status});

  final String? seasonId;
  final String query;
  final PaymentStatus? status;
}
