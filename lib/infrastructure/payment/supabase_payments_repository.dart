import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/payment/payment.dart';
import '../../domain/payment/payments_repository.dart';

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
      'P0001' when hint == 'invalid_transition' =>
        const InvalidPaymentTransitionFailure(),
      _ => PaymentUnavailableFailure('$code $message'),
    };
