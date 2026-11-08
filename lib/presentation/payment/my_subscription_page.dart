import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/payment/my_subscription.dart';
import '../common/open_url.dart';
import '../format/money.dart';
import '../season/season_membership_chip.dart';
import '../session/session_view_model.dart';
import 'how_to_pay_sheet.dart';
import 'my_subscription_view_model.dart';
import 'payment_labels.dart';

/// «Mi suscripción» (RF-011, RF-016).
class MySubscriptionPage extends StatelessWidget {
  const MySubscriptionPage({super.key, this.paymentResult, this.methodResult});

  /// `ok` or `cancelado` when coming back from saving a method.
  final String? methodResult;

  /// `ok` or `cancelado` when coming back from the provider checkout.
  final String? paymentResult;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => MySubscriptionViewModel(
      context.read<AppUseCases>(),
      clubId: context.read<SessionViewModel>().activeClub!.id,
    )..load(),
    child: _MySubscriptionView(
      paymentResult: paymentResult,
      methodResult: methodResult,
    ),
  );
}

class _MySubscriptionView extends StatelessWidget {
  const _MySubscriptionView({this.paymentResult, this.methodResult});

  final String? paymentResult;
  final String? methodResult;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MySubscriptionViewModel>();
    final subscription = viewModel.subscription;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi suscripción'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      body: switch ((viewModel.loadError, subscription)) {
        (final String error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: viewModel.load,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        (null, null) => const Center(child: CircularProgressIndicator()),
        (null, final MySubscription value) => RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (paymentResult == 'ok')
                const _ReturnNotice(
                  key: Key('payment-return-ok'),
                  icon: Icons.hourglass_top,
                  text:
                      'Estamos confirmando tu pago. En cuanto llegue la '
                      'confirmación verás tu cuota pagada; desliza hacia abajo '
                      'para actualizar.',
                ),
              if (paymentResult == 'cancelado')
                const _ReturnNotice(
                  key: Key('payment-return-cancelled'),
                  icon: Icons.info_outline,
                  text:
                      'No se ha completado el pago. Puedes intentarlo de nuevo '
                      'cuando quieras.',
                ),
              if (methodResult == 'ok')
                const _ReturnNotice(
                  key: Key('method-return-ok'),
                  icon: Icons.hourglass_top,
                  text:
                      'Estamos guardando tu método de pago. Aparecerá aquí en '
                      'unos segundos; desliza hacia abajo para actualizar.',
                ),
              _CurrentSeason(subscription: value),
              const SizedBox(height: 16),
              if (value.onlinePayments || viewModel.renewal.method != null) ...[
                _RenewalSection(renewal: viewModel.renewal),
                const SizedBox(height: 16),
              ],
              _NextCharges(subscription: value),
              const SizedBox(height: 24),
              Text(
                'Histórico de pagos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (viewModel.payments.isEmpty)
                Text(
                  'Todavía no tienes pagos registrados.',
                  key: const Key('payments-empty'),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final payment in viewModel.payments)
                  _PaymentTile(payment: payment),
            ],
          ),
        ),
      },
    );
  }
}

class _CurrentSeason extends StatelessWidget {
  const _CurrentSeason({required this.subscription});

  final MySubscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!subscription.hasSeason) {
      return const Card(
        key: Key('subscription-no-season'),
        child: ListTile(
          leading: Icon(Icons.event_busy),
          title: Text('Tu club todavía no ha abierto la temporada'),
          subtitle: Text('Aquí verás tu cuota cuando empiece.'),
        ),
      );
    }
    return Card(
      key: const Key('subscription-current'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Temporada ${subscription.seasonName}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (subscription.status != null)
              SeasonMembershipChip(status: subscription.status!),
            const SizedBox(height: 12),
            _Row(
              label: 'Cuota',
              value: subscription.feeCents == null
                  ? '—'
                  : subscription.feeCents == 0
                  ? 'Sin cuota'
                  : formatCents(subscription.feeCents!),
            ),
            _Row(
              label: 'Último método de pago',
              value: subscription.lastMethod == null
                  ? 'Sin método registrado'
                  : paymentMethodLabel(subscription.lastMethod!),
            ),
            if (subscription.canPayOnline) ...[
              const SizedBox(height: 12),
              const _SaveForRenewalCheckbox(),
              const _PayOnlineButton(),
            ],
            if (subscription.canPay) ...[
              const SizedBox(height: 8),
              (subscription.canPayOnline
                  ? OutlinedButton.icon
                  : FilledButton.icon)(
                key: const Key('subscription-how-to-pay'),
                onPressed: () => startFeePayment(
                  context,
                  useCases: context.read<AppUseCases>(),
                  clubId: context.read<MySubscriptionViewModel>().clubId,
                  seasonMembershipId: subscription.seasonMembershipId!,
                  feeCents: subscription.feeCents,
                ),
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  subscription.canPayOnline
                      ? 'Otras formas de pago'
                      : 'Cómo pagar',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _NextCharges extends StatelessWidget {
  const _NextCharges({required this.subscription});

  final MySubscription subscription;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('subscription-next-charges'),
    child: ListTile(
      leading: const Icon(Icons.event_repeat),
      title: const Text('Próximos cargos'),
      subtitle: Text(
        subscription.hasNextCharge
            ? 'Próximo cargo: ${formatCents(subscription.nextChargeCents!)} el '
                  '${formatLongDate(subscription.nextChargeOn!)}'
                  '${subscription.nextChargeSeason == null ? '' : ' · Temporada ${subscription.nextChargeSeason}'}. '
                  'Te avisaremos antes.'
            : 'No tienes cargos programados.',
        key: const Key('next-charge'),
      ),
    ),
  );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final MyPayment payment;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('my-payment-${payment.id}'),
    child: ListTile(
      title: Text(payment.concept),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              'Temporada ${payment.seasonName}',
              formatDate(payment.date),
              if (payment.method != null) paymentMethodLabel(payment.method!),
            ].join(' · '),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PaymentStatusChip(status: payment.status),
              if (payment.hasReceipt) _ReceiptButton(payment: payment),
            ],
          ),
        ],
      ),
      trailing: Text(
        formatCents(payment.amountCents),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
  );
}

class _ReceiptButton extends StatelessWidget {
  const _ReceiptButton({required this.payment});

  final MyPayment payment;

  Future<void> _download(BuildContext context) async {
    final viewModel = context.read<MySubscriptionViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = await viewModel.downloadReceipt(payment);
    } on String catch (error) {
      message = error;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy =
        context.watch<MySubscriptionViewModel>().downloadingId == payment.id;
    return TextButton.icon(
      key: Key('receipt-${payment.id}'),
      onPressed: busy ? null : () => _download(context),
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
      label: const Text('Descargar recibo'),
    );
  }
}

class _PayOnlineButton extends StatelessWidget {
  const _PayOnlineButton();

  Future<void> _pay(BuildContext context) async {
    final viewModel = context.read<MySubscriptionViewModel>();
    final openUrl = context.read<OpenUrl>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await openUrl(await viewModel.payOnline());
    } on String catch (message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<MySubscriptionViewModel>().startingPayment;
    return FilledButton.icon(
      key: const Key('subscription-pay-online'),
      onPressed: busy ? null : () => _pay(context),
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.credit_card),
      label: const Text('Pagar ahora con tarjeta o domiciliación'),
    );
  }
}

class _ReturnNotice extends StatelessWidget {
  const _ReturnNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: scheme.onSecondaryContainer),
        title: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// «4242», «Visa ···· 4242», «Cuenta ES ···· 3000».
String savedMethodLabel(SavedPaymentMethod method) {
  final last4 = method.last4 == null ? '' : ' ···· ${method.last4}';
  return switch (method.kind) {
    SavedMethodKind.card =>
      '${method.brand == null ? 'Tarjeta' : _brandName(method.brand!)}$last4',
    SavedMethodKind.sepaDebit =>
      'Domiciliación ${method.country ?? ''}$last4'.replaceAll('  ', ' '),
  };
}

String _brandName(String brand) => switch (brand) {
  'visa' => 'Visa',
  'mastercard' => 'Mastercard',
  'amex' => 'American Express',
  _ => 'Tarjeta ${brand[0].toUpperCase()}${brand.substring(1)}',
};

class _SaveForRenewalCheckbox extends StatelessWidget {
  const _SaveForRenewalCheckbox();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MySubscriptionViewModel>();
    return CheckboxListTile(
      key: const Key('save-for-renewal'),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: viewModel.saveForRenewal,
      onChanged: (value) => viewModel.setSaveForRenewal(value ?? false),
      title: const Text('Usar este método para renovar automáticamente'),
      subtitle: const Text('Te avisaremos antes de cada renovación'),
    );
  }
}

class _RenewalSection extends StatelessWidget {
  const _RenewalSection({required this.renewal});

  final RenewalSetup renewal;

  Future<void> _setUp(BuildContext context) async {
    final viewModel = context.read<MySubscriptionViewModel>();
    final openUrl = context.read<OpenUrl>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await openUrl(await viewModel.setUpMethod());
    } on String catch (message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _remove(BuildContext context) async {
    final viewModel = context.read<MySubscriptionViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar el método de pago?'),
        content: const Text(
          'La renovación automática se desactivará y tendrás que pagar la '
          'próxima cuota tú mismo. Tus pagos y recibos no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('remove-method-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    String message;
    try {
      message = await viewModel.removeMethod();
    } on String catch (error) {
      message = error;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = context.watch<MySubscriptionViewModel>().changingMethod;
    final method = renewal.method;
    return Card(
      key: const Key('renewal-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Renovación automática', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (method == null)
              Text(
                'Guarda una tarjeta o una cuenta bancaria y tu cuota se '
                'renovará sola cada temporada.',
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              Row(
                children: [
                  Icon(
                    method.kind == SavedMethodKind.card
                        ? Icons.credit_card
                        : Icons.account_balance_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      savedMethodLabel(method),
                      key: const Key('saved-method'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (renewal.isAutomatic)
                const Chip(
                  key: Key('auto-renew-on'),
                  avatar: Icon(Icons.autorenew, size: 16),
                  label: Text('Renovación automática activada'),
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (method != null)
                  TextButton(
                    key: const Key('remove-method'),
                    onPressed: busy ? null : () => _remove(context),
                    child: const Text('Eliminar método'),
                  ),
                OutlinedButton(
                  key: const Key('set-up-method'),
                  onPressed: busy ? null : () => _setUp(context),
                  child: Text(
                    method == null ? 'Guardar un método' : 'Cambiar método',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
