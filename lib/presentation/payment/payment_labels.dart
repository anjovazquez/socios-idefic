import 'package:flutter/material.dart';

import '../../domain/payment/payment.dart';

String paymentMethodLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Efectivo',
  PaymentMethod.transfer => 'Transferencia',
  PaymentMethod.bizum => 'Bizum',
  PaymentMethod.card => 'Tarjeta',
  PaymentMethod.sepa => 'Domiciliación',
  PaymentMethod.other => 'Otro',
};

String paymentFailureMessage(PaymentFailure failure) => switch (failure) {
  InvalidPaymentAmountFailure() => 'Escribe un importe mayor que 0',
  AlreadyPaidFailure() => 'Esta cuota ya está pagada',
  NotPayableFailure() => 'Esta temporada no tiene cuota pendiente',
  InvalidPaymentTransitionFailure() =>
    'Este pago ya no se puede cambiar en ese sentido',
  NoReceiptFailure() => 'Este pago no tiene recibo',
  PaymentPermissionFailure() =>
    'Solo el administrador del club puede registrar pagos',
  PaymentUnavailableFailure() =>
    'No hemos podido conectar. Inténtalo de nuevo en un momento',
};

/// Payment state with icon + text (DESIGN.md §2.2).
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.status});

  final PaymentStatus status;

  static String label(PaymentStatus status) => switch (status) {
    PaymentStatus.pending => 'Pendiente',
    PaymentStatus.paid => 'Pagado',
    PaymentStatus.failed => 'Fallido',
    PaymentStatus.cancelled => 'Anulado',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background) = switch (status) {
      PaymentStatus.paid => (
        Icons.check_circle_outline,
        scheme.primaryContainer,
      ),
      PaymentStatus.pending => (Icons.schedule, scheme.tertiaryContainer),
      PaymentStatus.failed => (Icons.error_outline, scheme.errorContainer),
      PaymentStatus.cancelled => (Icons.block, scheme.surfaceContainerHighest),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label(status)),
      backgroundColor: background,
    );
  }
}
