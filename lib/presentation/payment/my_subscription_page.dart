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
  const MySubscriptionPage({super.key, this.paymentResult});

  /// `ok` or `cancelado` when coming back from the provider checkout.
  final String? paymentResult;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => MySubscriptionViewModel(
      context.read<AppUseCases>(),
      clubId: context.read<SessionViewModel>().activeClub!.id,
    )..load(),
    child: _MySubscriptionView(paymentResult: paymentResult),
  );
}

class _MySubscriptionView extends StatelessWidget {
  const _MySubscriptionView({this.paymentResult});

  final String? paymentResult;

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
              _CurrentSeason(subscription: value),
              const SizedBox(height: 16),
              const _NextCharges(),
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
  const _NextCharges();

  @override
  Widget build(BuildContext context) => const Card(
    key: Key('subscription-next-charges'),
    child: ListTile(
      leading: Icon(Icons.event_repeat),
      title: Text('Próximos cargos'),
      subtitle: Text('No tienes cargos programados.'),
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
