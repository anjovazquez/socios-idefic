import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/season/renewal.dart';
import '../common/submit_dialog.dart';
import '../format/money.dart';
import 'renewal_view_model.dart';

/// Bulk renewal of the members of the previous season (RF-009).
class RenewalPage extends StatelessWidget {
  const RenewalPage({super.key, required this.seasonId, this.seasonName});

  final String seasonId;
  final String? seasonName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          RenewalViewModel(context.read<AppUseCases>(), seasonId: seasonId)
            ..load(),
      child: _RenewalView(seasonName: seasonName),
    );
  }
}

class _RenewalView extends StatelessWidget {
  const _RenewalView({this.seasonName});

  final String? seasonName;

  Future<void> _renew(BuildContext context) async {
    final viewModel = context.read<RenewalViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Renovar ${viewModel.selectedCount} socios?'),
        content: Text(
          'Quedarán en ${seasonName ?? 'la temporada'} pendientes de pago '
          '(los de 0 €, como socios). Total previsto: '
          '${formatCents(viewModel.totalCents)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-renewal'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Renovar'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      final message = await viewModel.renew();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editFee(BuildContext context, RenewalCandidate c) async {
    final viewModel = context.read<RenewalViewModel>();
    await showDialog<String>(
      context: context,
      builder: (_) => _FeeDialog(candidate: c, viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RenewalViewModel>();
    final theme = Theme.of(context);
    final previous = viewModel.previousSeasonName;
    return Scaffold(
      appBar: AppBar(
        title: Text('Renovar socios · ${seasonName ?? ''}'),
        leading: BackButton(onPressed: () => context.go('/club/seasons')),
      ),
      bottomNavigationBar: viewModel.candidates.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${viewModel.selectedCount} a renovar · '
                        '${viewModel.excludedCount} excluidos\n'
                        'Total previsto: ${formatCents(viewModel.totalCents)}',
                        key: const Key('renewal-summary'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    FilledButton(
                      key: const Key('renewal-submit'),
                      onPressed:
                          viewModel.isRenewing || viewModel.selectedCount == 0
                          ? null
                          : () => _renew(context),
                      child: Text('Renovar ${viewModel.selectedCount}'),
                    ),
                  ],
                ),
              ),
            ),
      body: switch (viewModel) {
        RenewalViewModel(isLoading: true, candidates: []) => const Center(
          child: CircularProgressIndicator(),
        ),
        RenewalViewModel(:final error?) when viewModel.candidates.isEmpty =>
          Center(child: Text(error)),
        RenewalViewModel(candidates: []) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No hay socios que renovar: la temporada anterior no tiene '
              'socios al día.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Socios al día en $previous. Desmarca a quien no quieras '
                'renovar y toca la cuota para cambiarla.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SwitchListTile(
              key: const Key('renewal-keep-custom'),
              title: const Text('Mantener cuotas personalizadas'),
              subtitle: const Text(
                'Exentos y descuentos de la temporada anterior',
              ),
              value: viewModel.keepCustomFees,
              onChanged: viewModel.setKeepCustomFees,
            ),
            if (viewModel.alreadyRenewedCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${viewModel.alreadyRenewedCount} ya renovados',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            CheckboxListTile(
              key: const Key('renewal-select-all'),
              title: const Text('Seleccionar todos'),
              value: viewModel.excludedCount == 0,
              onChanged: (value) => viewModel.selectAll(value ?? false),
            ),
            const Divider(height: 1),
            for (final c in viewModel.candidates)
              CheckboxListTile(
                key: Key('renewal-${c.email}'),
                value: c.alreadyRenewed || viewModel.isSelected(c),
                onChanged: c.alreadyRenewed ? null : (_) => viewModel.toggle(c),
                title: Text('${c.memberNumber ?? '–'} · ${c.displayName}'),
                subtitle: Text(
                  c.alreadyRenewed
                      ? 'Ya renovado'
                      : 'Antes ${formatCents(c.previousFeeCents)}'
                            '${c.previousWasCustom ? ' (personalizada)' : ''}',
                ),
                secondary: c.alreadyRenewed
                    ? null
                    : TextButton(
                        key: Key('renewal-fee-${c.email}'),
                        onPressed: () => _editFee(context, c),
                        child: Text(formatCents(viewModel.feeOf(c))),
                      ),
              ),
          ],
        ),
      },
    );
  }
}

class _FeeDialog extends StatefulWidget {
  const _FeeDialog({required this.candidate, required this.viewModel});

  final RenewalCandidate candidate;
  final RenewalViewModel viewModel;

  @override
  State<_FeeDialog> createState() => _FeeDialogState();
}

class _FeeDialogState extends State<_FeeDialog> {
  late final _fee = TextEditingController(
    text: centsToInput(widget.viewModel.feeOf(widget.candidate)),
  );

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SubmitDialog(
    title: 'Cuota de ${widget.candidate.displayName}',
    action: 'Aplicar',
    saveKey: const Key('renewal-fee-save'),
    onSubmit: () => widget.viewModel.setFee(widget.candidate, _fee.text),
    builder: (context, _) => [
      TextField(
        key: const Key('renewal-fee-field'),
        controller: _fee,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Cuota de la nueva temporada',
          suffixText: '€',
        ),
      ),
    ],
  );
}
