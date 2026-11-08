import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/payment/online_payments.dart';
import '../../domain/payment/payment.dart';
import '../common/open_url.dart';
import 'payment_labels.dart';

/// The club connects its Stripe account to take online payments (ADR-001).
class OnlinePaymentsViewModel extends ChangeNotifier {
  OnlinePaymentsViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  OnlinePaymentsStatus? _status;
  OnlinePaymentsStatus? get status => _status;

  bool _busy = false;
  bool get busy => _busy;

  /// [refresh] asks Stripe (back from the onboarding).
  Future<void> load({bool refresh = false}) async {
    try {
      _status = refresh
          ? await _useCases.refreshOnlinePaymentsStatus(clubId)
          : await _useCases.getOnlinePaymentsStatus(clubId);
    } catch (_) {
      _status ??= OnlinePaymentsStatus.notConnected;
    }
    notifyListeners();
  }

  /// Returns the Stripe onboarding page, or throws the error message.
  Future<Uri> connect() =>
      _run(() => _useCases.startOnlinePaymentsOnboarding(clubId));

  Future<void> checkStatus() => _run(() => load(refresh: true));

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } on PaymentFailure catch (failure) {
      throw paymentFailureMessage(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw paymentFailureMessage(const PaymentUnavailableFailure());
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

class OnlinePaymentsSection extends StatelessWidget {
  const OnlinePaymentsSection({
    super.key,
    required this.clubId,
    this.returningFromStripe = false,
  });

  final String clubId;

  /// Back from the Stripe onboarding: read the account status again.
  final bool returningFromStripe;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        OnlinePaymentsViewModel(context.read<AppUseCases>(), clubId: clubId)
          ..load(refresh: returningFromStripe),
    child: const _Section(),
  );
}

class _Section extends StatelessWidget {
  const _Section();

  Future<void> _connect(BuildContext context) async {
    final viewModel = context.read<OnlinePaymentsViewModel>();
    final openUrl = context.read<OpenUrl>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await openUrl(await viewModel.connect());
    } on String catch (message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _check(BuildContext context) async {
    final viewModel = context.read<OnlinePaymentsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await viewModel.checkStatus();
    } on String catch (message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnlinePaymentsViewModel>();
    final theme = Theme.of(context);
    final status = viewModel.status;
    final (icon, text) = switch (status) {
      null => (Icons.hourglass_empty, 'Comprobando…'),
      OnlinePaymentsStatus.notConnected => (
        Icons.link_off,
        'Conecta el club con Stripe para que los socios paguen con tarjeta '
            'o domiciliación. El dinero llega a la cuenta del club.',
      ),
      OnlinePaymentsStatus.pendingVerification => (
        Icons.schedule,
        'Stripe está verificando los datos del club. Completa la '
            'verificación para activar el pago online.',
      ),
      OnlinePaymentsStatus.active => (
        Icons.check_circle_outline,
        'Pago online activo: los socios pueden pagar su cuota desde la app.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pagos online', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          key: Key('online-payments-${status?.name ?? 'loading'}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(text),
        ),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (status == OnlinePaymentsStatus.pendingVerification)
              TextButton(
                key: const Key('online-payments-check'),
                onPressed: viewModel.busy ? null : () => _check(context),
                child: const Text('Comprobar estado'),
              ),
            if (status == OnlinePaymentsStatus.notConnected ||
                status == OnlinePaymentsStatus.pendingVerification)
              FilledButton.tonal(
                key: const Key('online-payments-connect'),
                onPressed: viewModel.busy ? null : () => _connect(context),
                child: Text(
                  status == OnlinePaymentsStatus.notConnected
                      ? 'Conectar con Stripe'
                      : 'Completar verificación',
                ),
              ),
          ],
        ),
      ],
    );
  }
}
