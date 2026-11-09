import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/payment/club_payments.dart';
import '../../domain/payment/payment.dart';
import '../format/money.dart';
import '../session/session_view_model.dart';
import 'club_payments_view_model.dart';
import 'payment_labels.dart';

/// Payments of the club for its admin (RF-018, §16 Pagos).
class ClubPaymentsPage extends StatelessWidget {
  const ClubPaymentsPage({super.key, this.onlyPending = false});

  /// Opens filtered on pending fees (dashboard shortcut).
  final bool onlyPending;

  @override
  Widget build(BuildContext context) {
    final club = context.read<SessionViewModel>().activeClub;
    if (club == null || !club.canAdminister) {
      return const Scaffold(
        body: Center(
          child: Text('Solo el administrador del club puede ver esta pantalla'),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (context) => ClubPaymentsViewModel(
        context.read<AppUseCases>(),
        clubId: club.id,
        initialStatus: onlyPending ? PaymentStatus.pending : null,
      )..load(),
      child: const _ClubPaymentsView(),
    );
  }
}

class _ClubPaymentsView extends StatefulWidget {
  const _ClubPaymentsView();

  @override
  State<_ClubPaymentsView> createState() => _ClubPaymentsViewState();
}

class _ClubPaymentsViewState extends State<_ClubPaymentsView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => context.read<ClubPaymentsViewModel>().search(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClubPaymentsViewModel>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('payments-search'),
                    onChanged: _onSearch,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar socio',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  key: const Key('payments-season'),
                  value: viewModel.filter.seasonId,
                  onChanged: viewModel.selectSeason,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas las temporadas'),
                    ),
                    for (final season in viewModel.seasons)
                      DropdownMenuItem(
                        value: season.id,
                        child: Text(season.name),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final (status, label) in [
                  (null, 'Todos'),
                  (PaymentStatus.paid, 'Pagados'),
                  (PaymentStatus.pending, 'Pendientes'),
                  (PaymentStatus.failed, 'Fallidos'),
                  (PaymentStatus.cancelled, 'Anulados'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('payments-filter-${status?.name ?? 'all'}'),
                      label: Text(label),
                      selected: viewModel.filter.status == status,
                      onSelected: (_) => viewModel.selectStatus(status),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              key: const Key('payments-totals'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _Total(
                        key: const Key('payments-paid-total'),
                        label: 'Cobrado',
                        value: formatCents(viewModel.paidCents),
                      ),
                    ),
                    Expanded(
                      child: _Total(
                        key: const Key('payments-pending-total'),
                        label: 'Pendiente',
                        value: formatCents(viewModel.pendingCents),
                      ),
                    ),
                    Text(
                      viewModel.total == 1
                          ? '1 movimiento'
                          : '${viewModel.total} movimientos',
                      key: const Key('payments-count'),
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (viewModel) {
              ClubPaymentsViewModel(isLoading: true, lines: []) => const Center(
                child: CircularProgressIndicator(),
              ),
              ClubPaymentsViewModel(:final loadError?) => Center(
                child: Text(loadError),
              ),
              ClubPaymentsViewModel(lines: []) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No hay pagos con estos filtros',
                    key: Key('payments-empty'),
                  ),
                ),
              ),
              _ => ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final line in viewModel.lines) _PaymentLineTile(line),
                  if (viewModel.hasMore)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton(
                        key: const Key('payments-more'),
                        onPressed: viewModel.isLoading
                            ? null
                            : viewModel.loadMore,
                        child: const Text('Ver más'),
                      ),
                    ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _PaymentLineTile extends StatelessWidget {
  const _PaymentLineTile(this.line);

  final ClubPaymentLine line;

  Future<void> _download(BuildContext context) async {
    final viewModel = context.read<ClubPaymentsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = await viewModel.downloadReceipt(line);
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
        context.watch<ClubPaymentsViewModel>().downloadingId == line.id;
    final details = [
      if (line.memberNumber != null) 'Nº ${line.memberNumber}',
      'Temporada ${line.seasonName}',
      if (line.date != null) formatDate(line.date!.toLocal()),
      if (line.method != null) paymentMethodLabel(line.method!),
      if (line.paymentId == null)
        line.status == PaymentStatus.pending ? 'Cuota sin pagar' : line.concept,
    ].join(' · ');
    return Card(
      key: Key('club-payment-${line.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(line.memberName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PaymentStatusChip(status: line.status),
                if (line.hasReceipt)
                  TextButton.icon(
                    key: Key('club-receipt-${line.id}'),
                    onPressed: busy ? null : () => _download(context),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('Recibo'),
                  ),
              ],
            ),
          ],
        ),
        trailing: Text(
          formatCents(line.amountCents),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}
