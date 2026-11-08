import 'package:flutter/material.dart';

import '../../application/app_use_cases.dart';
import '../../domain/payment/payment_gateway.dart';
import '../format/money.dart';

/// Starts the payment of a pending fee: with the manual provider it shows
/// the club instructions (§9); online payment arrives with VS-021.
Future<void> startFeePayment(
  BuildContext context, {
  required AppUseCases useCases,
  required String clubId,
  required String seasonMembershipId,
  int? feeCents,
}) async {
  final start = await useCases.startPayment(
    clubId: clubId,
    seasonMembershipId: seasonMembershipId,
  );
  if (!context.mounted) return;
  switch (start) {
    case ManualPaymentStart(:final instructions):
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cómo pagar tu cuota'
                  '${feeCents == null ? '' : ' de ${formatCents(feeCents)}'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  instructions ??
                      'Tu club todavía no ha indicado cómo pagar. Ponte en '
                          'contacto con él.',
                  key: const Key('payment-instructions-text'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Cuando el club registre tu pago, tu carnet se activará '
                  'solo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    case RedirectPaymentStart():
      // Online payment arrives with the real provider (VS-021).
      break;
  }
}
