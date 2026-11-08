import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/payment/club_payments.dart';
import '../../domain/payment/my_subscription.dart';
import '../../domain/payment/payment.dart';
import '../../domain/season/season_membership.dart';
import '../../domain/payment/payments_repository.dart';
import '../../domain/payment/receipt.dart';

class SupabasePaymentsRepository implements PaymentsRepository {
  const SupabasePaymentsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Payment>> getSeasonPayments(String seasonMembershipId) =>
      _guard(() async {
        final rows = await _client
            .from('payments')
            .select(
              'id, season_membership_id, amount_cents, concept, status, '
              'provider, method, provider_reference, paid_at, created_at',
            )
            .eq('season_membership_id', seasonMembershipId)
            .order('created_at', ascending: false);
        return rows.map(paymentFromRow).toList();
      });

  @override
  Future<void> recordManualPayment({
    required String seasonMembershipId,
    required PaymentMethod method,
    int? amountCents,
    DateTime? paidOn,
    String? reference,
  }) => _guard(
    () => _client.rpc<void>(
      'record_manual_payment',
      params: {
        'p_season_membership_id': seasonMembershipId,
        'p_method': method.name,
        'p_amount_cents': amountCents,
        'p_paid_on': paidOn?.toIso8601String().substring(0, 10),
        'p_reference': reference,
      },
    ),
  );

  @override
  Future<void> setStatus(String paymentId, PaymentStatus status) => _guard(
    () => _client.rpc<void>(
      'set_payment_status',
      params: {'p_payment_id': paymentId, 'p_status': status.name},
    ),
  );

  @override
  Future<String?> getPaymentInstructions(String clubId) => _guard(
    () async => await _client.rpc<String?>(
      'get_payment_instructions',
      params: {'p_club_id': clubId},
    ),
  );

  @override
  Future<void> setPaymentInstructions(String clubId, String instructions) =>
      _guard(
        () => _client.rpc<void>(
          'set_payment_instructions',
          params: {'p_club_id': clubId, 'p_instructions': instructions},
        ),
      );

  @override
  Future<MySubscription> getMySubscription(String clubId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_my_subscription',
      params: {'p_club_id': clubId},
    );
    return rows.isEmpty
        ? const MySubscription()
        : mySubscriptionFromRow(rows.first as Map<String, dynamic>);
  });

  @override
  Future<List<MyPayment>> getMyPayments(String clubId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_my_payments',
      params: {'p_club_id': clubId},
    );
    return rows.cast<Map<String, dynamic>>().map(myPaymentFromRow).toList();
  });

  @override
  Future<ClubPaymentsPage> getClubPayments(
    String clubId, {
    ClubPaymentsFilter filter = const ClubPaymentsFilter(),
    int offset = 0,
    int limit = 50,
  }) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_club_payments',
      params: {
        'p_club_id': clubId,
        'p_season_id': filter.seasonId,
        'p_query': filter.query.trim().isEmpty ? null : filter.query.trim(),
        'p_status': filter.status?.name,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return clubPaymentsPageFromRows(rows.cast<Map<String, dynamic>>());
  });

  @override
  Future<Receipt> getReceipt(String paymentId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_receipt',
      params: {'p_payment_id': paymentId},
    );
    if (rows.isEmpty) throw const NoReceiptFailure();
    final row = rows.first as Map<String, dynamic>;
    final logoPath = row['club_logo_path'] as String?;
    return receiptFromRow(
      row,
      logoUrl: logoPath == null
          ? null
          : _client.storage.from('club-assets').getPublicUrl(logoPath),
    );
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapPaymentError(error.code, error.message, error.hint);
    } on PaymentFailure {
      rethrow;
    } catch (error) {
      throw PaymentUnavailableFailure(error);
    }
  }
}

Payment paymentFromRow(Map<String, dynamic> row) => Payment(
  id: row['id'] as String,
  seasonMembershipId: row['season_membership_id'] as String,
  amountCents: row['amount_cents'] as int,
  concept: row['concept'] as String,
  status: PaymentStatus.values.byName(row['status'] as String),
  provider: PaymentProvider.values.byName(row['provider'] as String),
  method: switch (row['method']) {
    final String name => PaymentMethod.values.byName(name),
    _ => null,
  },
  reference: row['provider_reference'] as String?,
  paidAt: switch (row['paid_at']) {
    final String value => DateTime.parse(value),
    _ => null,
  },
  createdAt: DateTime.parse(row['created_at'] as String),
);

PaymentFailure mapPaymentError(String? code, String message, String? hint) =>
    switch (code) {
      '42501' => const PaymentPermissionFailure(),
      '22023' when message.contains('amount') =>
        const InvalidPaymentAmountFailure(),
      'P0001' when hint == 'already_paid' => const AlreadyPaidFailure(),
      'P0001' when hint == 'not_payable' => const NotPayableFailure(),
      'P0001' when hint == 'no_receipt' => const NoReceiptFailure(),
      'P0002' => const NoReceiptFailure(),
      'P0001' when hint == 'invalid_transition' =>
        const InvalidPaymentTransitionFailure(),
      _ => PaymentUnavailableFailure('$code $message'),
    };

PaymentMethod? _methodOf(Object? name) => switch (name) {
  final String value => PaymentMethod.values.byName(value),
  _ => null,
};

MySubscription mySubscriptionFromRow(Map<String, dynamic> row) =>
    MySubscription(
      seasonName: row['season_name'] as String?,
      seasonMembershipId: row['season_membership_id'] as String?,
      feeCents: row['fee_cents'] as int?,
      status: switch (row['status']) {
        final String name => seasonMembershipStatusFromName(name),
        _ => null,
      },
      lastMethod: _methodOf(row['payment_method']),
      nextChargeCents: row['next_charge_cents'] as int?,
      nextChargeOn: switch (row['next_charge_on']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
    );

MyPayment myPaymentFromRow(Map<String, dynamic> row) => MyPayment(
  id: row['payment_id'] as String,
  seasonName: row['season_name'] as String,
  concept: row['concept'] as String,
  amountCents: row['amount_cents'] as int,
  date: DateTime.parse(row['payment_date'] as String),
  status: PaymentStatus.values.byName(row['status'] as String),
  method: _methodOf(row['method']),
  receiptNumber: row['receipt_number'] as int?,
);

Receipt receiptFromRow(Map<String, dynamic> row, {String? logoUrl}) {
  final name = [
    row['member_first_name'] as String?,
    row['member_last_name'] as String?,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
  return Receipt(
    paymentId: row['payment_id'] as String,
    number: row['receipt_number'] as int,
    clubName: row['club_name'] as String,
    clubCode: row['club_code'] as String,
    clubPrimaryColor: row['club_primary_color'] as String?,
    clubLogoUrl: logoUrl,
    memberName: name.isEmpty ? (row['member_email'] as String? ?? '') : name,
    memberNumber: row['member_number'] as int?,
    seasonName: row['season_name'] as String,
    concept: row['concept'] as String,
    amountCents: row['amount_cents'] as int,
    method: _methodOf(row['method']),
    paidAt: DateTime.parse(row['paid_at'] as String),
  );
}

ClubPaymentsPage clubPaymentsPageFromRows(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return ClubPaymentsPage.empty;
  final first = rows.first;
  return ClubPaymentsPage(
    lines: rows.map(clubPaymentLineFromRow).toList(),
    total: first['total_count'] as int,
    paidCents: first['paid_cents'] as int,
    pendingCents: first['pending_cents'] as int,
  );
}

ClubPaymentLine clubPaymentLineFromRow(Map<String, dynamic> row) {
  final email = row['member_email'] as String;
  final name = [
    row['member_first_name'] as String?,
    row['member_last_name'] as String?,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
  return ClubPaymentLine(
    paymentId: row['payment_id'] as String?,
    seasonMembershipId: row['season_membership_id'] as String,
    seasonId: row['season_id'] as String,
    seasonName: row['season_name'] as String,
    memberName: name.isEmpty ? email : name,
    memberEmail: email,
    memberNumber: row['member_number'] as int?,
    concept: row['concept'] as String,
    amountCents: row['amount_cents'] as int,
    date: switch (row['payment_date']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
    status: PaymentStatus.values.byName(row['status'] as String),
    provider: switch (row['provider']) {
      final String value => PaymentProvider.values.byName(value),
      _ => null,
    },
    method: _methodOf(row['method']),
    receiptNumber: row['receipt_number'] as int?,
  );
}
