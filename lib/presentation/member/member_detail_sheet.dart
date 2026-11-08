import 'package:flutter/material.dart';

import '../../domain/member/club_member.dart';
import '../../domain/season/season_membership.dart';
import '../common/submit_dialog.dart';
import '../format/money.dart';
import '../payment/payment_labels.dart';
import '../payment/record_payment_dialog.dart';
import '../season/season_membership_chip.dart';
import '../../domain/payment/payment.dart';
import 'member_status_chip.dart';
import 'members_view_model.dart';

/// Member record for the club admin, with leave / come back actions.
class MemberDetailSheet extends StatelessWidget {
  const MemberDetailSheet({
    super.key,
    required this.member,
    required this.viewModel,
  });

  final ClubMember member;
  final MembersViewModel viewModel;

  Future<void> _deactivate(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Dar de baja a ${member.displayName}?'),
        content: const Text(
          'Dejará de ver el club en la app. Conservará su número de socio y '
          'su historial, y podrás reactivarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-deactivate-member'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await _run(navigator, messenger, () => viewModel.deactivate(member));
  }

  Future<void> _run(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    Future<String> Function() action,
  ) async {
    try {
      final message = await action();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _regenerate(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Regenerar el carnet?'),
        content: Text(
          'El QR actual de ${member.displayName} dejará de servir. Úsalo si '
          'el carnet se ha compartido o perdido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-regenerate-card'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await _run(navigator, messenger, () => viewModel.regenerateCard(member));
  }

  Future<void> _recordPayment(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = await showDialog<String>(
      context: context,
      builder: (_) => RecordPaymentDialog(
        memberName: member.displayName,
        feeCents: member.seasonFeeCents ?? 0,
        onSubmit: (method, amount, reference) => viewModel.recordPayment(
          member,
          method: method,
          amount: amount,
          reference: reference,
        ),
      ),
    );
    if (confirmation == null) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(confirmation)));
  }

  Future<void> _changeFee(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = await showDialog<String>(
      context: context,
      builder: (_) => _MemberFeeDialog(member: member, viewModel: viewModel),
    );
    if (confirmation == null) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(confirmation)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthDate = member.birthDate;
    final seasonStatus = member.seasonStatus;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FutureBuilder<String?>(
                  future: viewModel.photoUrl(member),
                  builder: (context, snapshot) => CircleAvatar(
                    radius: 32,
                    backgroundImage: snapshot.data == null
                        ? null
                        : NetworkImage(snapshot.data!),
                    onBackgroundImageError: snapshot.data == null
                        ? null
                        : (_, _) {},
                    child: snapshot.data == null
                        ? const Icon(Icons.person, size: 32)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        'Socio nº ${member.memberNumber ?? '–'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                MemberStatusChip(status: member.status),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline),
              title: Text(member.email),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: Text(member.phone ?? 'Sin teléfono'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(
                birthDate == null
                    ? 'Sin fecha de nacimiento'
                    : '${birthDate.day.toString().padLeft(2, '0')}/'
                          '${birthDate.month.toString().padLeft(2, '0')}/'
                          '${birthDate.year}',
              ),
            ),
            if (member.seasonMembershipId != null && seasonStatus != null) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Temporada actual · '
                      '${formatCents(member.seasonFeeCents ?? 0)}',
                      key: const Key('member-season-fee'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  SeasonMembershipChip(status: seasonStatus),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    key: const Key('member-change-fee'),
                    onPressed: () => _changeFee(context),
                    child: const Text('Cambiar cuota'),
                  ),
                  TextButton(
                    key: const Key('member-regenerate-card'),
                    onPressed: () => _regenerate(context),
                    child: const Text('Regenerar carnet'),
                  ),
                  if (seasonStatus == SeasonMembershipStatus.pendingPayment)
                    TextButton(
                      key: const Key('member-record-payment'),
                      onPressed: () => _recordPayment(context),
                      child: const Text('Registrar pago'),
                    ),
                ],
              ),
            ],
            _Payments(member: member, viewModel: viewModel),
            _History(member: member, viewModel: viewModel),
            const SizedBox(height: 8),
            if (member.isClubAdmin)
              Text(
                'Es el administrador del club',
                style: theme.textTheme.bodySmall,
              )
            else if (member.status == MemberStatus.inactive)
              FilledButton.icon(
                key: const Key('member-reactivate'),
                onPressed: () => _run(
                  Navigator.of(context),
                  ScaffoldMessenger.of(context),
                  () => viewModel.reactivate(member),
                ),
                icon: const Icon(Icons.undo),
                label: const Text('Reactivar'),
              )
            else
              OutlinedButton.icon(
                key: const Key('member-deactivate'),
                onPressed: () => _deactivate(context),
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Dar de baja'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Seasons of the member since their first one (§7).
class _History extends StatelessWidget {
  const _History({required this.member, required this.viewModel});

  final ClubMember member;
  final MembersViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<MemberSeason>>(
      future: viewModel.seasons(member),
      builder: (context, snapshot) {
        final seasons = snapshot.data ?? const [];
        if (seasons.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const Key('member-history'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Text('Histórico', style: theme.textTheme.titleSmall),
            for (final season in seasons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(season.seasonName)),
                    if (season.feeCents case final fee?)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(formatCents(fee)),
                      ),
                    SeasonMembershipChip(status: season.status),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MemberFeeDialog extends StatefulWidget {
  const _MemberFeeDialog({required this.member, required this.viewModel});

  final ClubMember member;
  final MembersViewModel viewModel;

  @override
  State<_MemberFeeDialog> createState() => _MemberFeeDialogState();
}

class _MemberFeeDialogState extends State<_MemberFeeDialog> {
  late final _fee = TextEditingController(
    text: centsToInput(widget.member.seasonFeeCents ?? 0),
  );

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SubmitDialog(
    title: 'Cuota de ${widget.member.displayName}',
    action: 'Guardar',
    saveKey: const Key('member-fee-save'),
    onSubmit: () => widget.viewModel.changeFee(widget.member, _fee.text),
    builder: (context, _) => [
      TextField(
        key: const Key('member-fee-field'),
        controller: _fee,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Cuota de esta temporada',
          suffixText: '€',
          helperText: '0 € para socios exentos u honoríficos',
        ),
      ),
    ],
  );
}

/// Payments of the current season, with "Anular" when allowed (RF-015).
class _Payments extends StatelessWidget {
  const _Payments({required this.member, required this.viewModel});

  final ClubMember member;
  final MembersViewModel viewModel;

  Future<void> _cancel(BuildContext context, Payment payment) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Anular este pago?'),
        content: Text(
          '${formatCents(payment.amountCents)} · ${payment.concept}. Si era '
          'el único pago, la cuota vuelve a quedar pendiente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-cancel-payment'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Anular pago'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      final message = await viewModel.cancelPayment(member, payment);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Payment>>(
      future: viewModel.payments(member),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? const [];
        if (payments.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const Key('member-payments'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Text('Pagos', style: theme.textTheme.titleSmall),
            for (final payment in payments)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        formatCents(payment.amountCents),
                        if (payment.method case final method?)
                          paymentMethodLabel(method),
                        if (payment.paidAt case final date?) formatDate(date),
                      ].join(' · '),
                    ),
                  ),
                  PaymentStatusChip(status: payment.status),
                  if (payment.canBeCancelled &&
                      payment.status != PaymentStatus.cancelled)
                    IconButton(
                      key: Key('cancel-payment-${payment.id}'),
                      tooltip: 'Anular pago',
                      icon: const Icon(Icons.undo),
                      onPressed: () => _cancel(context, payment),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
