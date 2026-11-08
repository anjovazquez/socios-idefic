import 'package:flutter/material.dart';

import '../../domain/payment/payment.dart';
import '../common/submit_dialog.dart';
import '../format/money.dart';
import 'payment_labels.dart';

/// The admin records a fee paid outside the app (manual provider).
class RecordPaymentDialog extends StatefulWidget {
  const RecordPaymentDialog({
    super.key,
    required this.memberName,
    required this.feeCents,
    required this.onSubmit,
  });

  final String memberName;
  final int feeCents;
  final Future<String> Function(
    PaymentMethod method,
    String amount,
    String reference,
  )
  onSubmit;

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  late final _amount = TextEditingController(
    text: centsToInput(widget.feeCents),
  );
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.transfer;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SubmitDialog(
    title: 'Registrar pago de ${widget.memberName}',
    action: 'Registrar',
    saveKey: const Key('record-payment-save'),
    onSubmit: () => widget.onSubmit(_method, _amount.text, _reference.text),
    builder: (context, refresh) => [
      Wrap(
        spacing: 8,
        children: [
          for (final method in manualPaymentMethods)
            ChoiceChip(
              key: Key('record-payment-method-${method.name}'),
              label: Text(paymentMethodLabel(method)),
              selected: _method == method,
              onSelected: (_) {
                _method = method;
                refresh();
              },
            ),
        ],
      ),
      TextField(
        key: const Key('record-payment-amount'),
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Importe',
          suffixText: '€',
        ),
      ),
      TextField(
        key: const Key('record-payment-reference'),
        controller: _reference,
        decoration: const InputDecoration(
          labelText: 'Referencia (opcional)',
          helperText: 'Nº de transferencia, recibo de Bizum…',
        ),
      ),
    ],
  );
}
