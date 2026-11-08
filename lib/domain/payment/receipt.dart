import 'payment.dart';

/// Receipt of a paid fee with the data at payment time (RF-017).
class Receipt {
  const Receipt({
    required this.paymentId,
    required this.number,
    required this.clubName,
    required this.clubCode,
    required this.memberName,
    required this.seasonName,
    required this.concept,
    required this.amountCents,
    required this.paidAt,
    this.clubPrimaryColor,
    this.clubLogoUrl,
    this.memberNumber,
    this.method,
  });

  final String paymentId;

  /// Correlative per club.
  final int number;
  final String clubName;
  final String clubCode;
  final String? clubPrimaryColor;
  final String? clubLogoUrl;
  final String memberName;
  final int? memberNumber;
  final String seasonName;
  final String concept;
  final int amountCents;
  final PaymentMethod? method;
  final DateTime paidAt;

  /// Visible receipt code, e.g. `IDEFIC-0002`.
  String get code => '$clubCode-${number.toString().padLeft(4, '0')}';

  String get fileName => 'recibo-$code.pdf';
}

/// Turns a receipt into a document the user keeps (PDF download or share).
abstract interface class ReceiptRenderer {
  Future<void> deliver(Receipt receipt);
}
