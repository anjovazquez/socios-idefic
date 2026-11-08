import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/card/membership_card.dart';
import '../../domain/payment/payment_gateway.dart';
import '../format/money.dart';
import '../session/session_view_model.dart';
import 'card_qr.dart';
import 'membership_card_view.dart';

/// «Mi carnet» (RF-019, RF-021).
class MyCardPage extends StatefulWidget {
  const MyCardPage({super.key});

  @override
  State<MyCardPage> createState() => _MyCardPageState();
}

class _MyCardPageState extends State<MyCardPage> {
  late final Future<MembershipCard> _card = context
      .read<AppUseCases>()
      .getMyCard(context.read<SessionViewModel>().activeClub!.id);

  Widget? _qrOf(MembershipCard card) =>
      card.cardToken == null ? null : CardQr(token: card.cardToken!);

  Future<void> _howToPay(MembershipCard card) async {
    final start = await context.read<AppUseCases>().startPayment(
      clubId: context.read<SessionViewModel>().activeClub!.id,
      seasonMembershipId: card.seasonMembershipId!,
    );
    if (!mounted) return;
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
                    '${card.feeCents == null ? '' : ' de ${formatCents(card.feeCents!)}'}',
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

  void _showFullScreen(MembershipCard card) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(title: const Text('Mi carnet')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RotatedBox(
                quarterTurns:
                    MediaQuery.of(context).size.width <
                        MediaQuery.of(context).size.height
                    ? 1
                    : 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: MembershipCardView(card: card, qr: _qrOf(card)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi carnet'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      body: FutureBuilder<MembershipCard>(
        future: _card,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'No hemos podido cargar tu carnet. Inténtalo de nuevo en un '
                'momento',
              ),
            );
          }
          final card = snapshot.data;
          if (card == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: switch (card.state) {
                  CardState.active => MembershipCardView(
                    card: card,
                    qr: _qrOf(card),
                  ),
                  _ => Opacity(
                    opacity: 0.45,
                    child: ExcludeSemantics(
                      child: MembershipCardView(card: card),
                    ),
                  ),
                },
              ),
              const SizedBox(height: 16),
              switch (card.state) {
                CardState.active => FilledButton.icon(
                  key: const Key('card-fullscreen'),
                  onPressed: () => _showFullScreen(card),
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Mostrar en grande'),
                ),
                CardState.pendingPayment => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Notice(
                      key: const Key('card-pending'),
                      icon: Icons.schedule,
                      text:
                          'Tu carnet de la temporada ${card.seasonName} se '
                          'activará cuando se complete el pago de la cuota.',
                    ),
                    const SizedBox(height: 8),
                    if (card.seasonMembershipId != null)
                      FilledButton.icon(
                        key: const Key('card-how-to-pay'),
                        onPressed: () => _howToPay(card),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Cómo pagar'),
                      ),
                  ],
                ),
                CardState.notRenewed => _Notice(
                  key: const Key('card-not-renewed'),
                  icon: Icons.info_outline,
                  text:
                      'No eres socio de la temporada ${card.seasonName}. '
                      'Habla con tu club si quieres renovar.',
                ),
                CardState.noSeason => const _Notice(
                  key: Key('card-no-season'),
                  icon: Icons.event_busy,
                  text:
                      'Tu club todavía no ha abierto la temporada. Tu carnet '
                      'aparecerá aquí.',
                ),
              },
              if (card.isActive)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Enseña tu carnet en la puerta y en los comercios con '
                    'ventajas para socios.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
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
