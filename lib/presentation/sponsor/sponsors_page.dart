import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/sponsor/sponsor.dart';
import '../club/image_picking.dart';
import '../session/session_view_model.dart';
import 'sponsor_dialogs.dart';
import 'sponsor_widgets.dart';
import 'sponsors_view_model.dart';

/// Sponsors of the club for its admin (RF-026…RF-028).
class SponsorsPage extends StatelessWidget {
  const SponsorsPage({super.key});

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
      create: (context) => SponsorsViewModel(
        context.read<AppUseCases>(),
        clubId: club.id,
        pickImage: context.read<PickImage>(),
      )..load(),
      child: const _SponsorsView(),
    );
  }
}

class _SponsorsView extends StatelessWidget {
  const _SponsorsView();

  Future<void> _show(BuildContext context, Widget dialog) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = await showDialog<String>(
      context: context,
      builder: (_) => dialog,
    );
    if (confirmation != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(confirmation)));
    }
  }

  Future<void> _toggle(
    BuildContext context,
    Sponsor sponsor,
    bool active,
  ) async {
    final viewModel = context.read<SponsorsViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = await viewModel.setActive(sponsor, active);
    } on String catch (error) {
      message = error;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SponsorsViewModel>();
    final theme = Theme.of(context);
    final active = viewModel.activeSeason;
    final candidates = viewModel.renewalCandidates;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrocinadores'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-sponsor'),
        onPressed: () => _show(context, SponsorDialog(viewModel: viewModel)),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nuevo patrocinador'),
      ),
      body: switch (viewModel) {
        SponsorsViewModel(isLoading: true, sponsors: []) => const Center(
          child: CircularProgressIndicator(),
        ),
        SponsorsViewModel(:final loadError?) => Center(child: Text(loadError)),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (active != null && candidates.isNotEmpty)
              Card(
                key: const Key('sponsors-renewal'),
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.autorenew),
                  title: Text(
                    candidates.length == 1
                        ? '1 patrocinador de la temporada anterior sin renovar'
                        : '${candidates.length} patrocinadores de la temporada '
                              'anterior sin renovar',
                  ),
                  subtitle: Text(
                    'No pasan solos a ${active.name}: renuévalos si siguen.',
                  ),
                  trailing: TextButton(
                    key: const Key('sponsors-renew'),
                    onPressed: () => _show(
                      context,
                      RenewSponsorsDialog(viewModel: viewModel),
                    ),
                    child: const Text('Renovar'),
                  ),
                ),
              ),
            if (viewModel.sponsors.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay patrocinadores. Da de alta el primero y '
                  'asócialo a la temporada.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final sponsor in viewModel.sponsors)
              Card(
                key: Key('sponsor-${sponsor.name}'),
                child: ListTile(
                  onTap: () => _show(
                    context,
                    SponsorDialog(viewModel: viewModel, sponsor: sponsor),
                  ),
                  leading: Opacity(
                    opacity: sponsor.isActive ? 1 : 0.45,
                    child: SponsorLogo(sponsor: sponsor, size: 48),
                  ),
                  title: Text(sponsor.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sponsor.websiteUrl != null) Text(sponsor.websiteUrl!),
                      Text(
                        sponsor.seasonNames.isEmpty
                            ? 'Sin temporada'
                            : 'Temporadas: ${sponsor.seasonNames.join(', ')}',
                        key: Key('sponsor-seasons-${sponsor.name}'),
                      ),
                      if (!sponsor.isActive)
                        Text(
                          'Desactivado: no se muestra a los socios',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: Switch(
                    key: Key('sponsor-active-${sponsor.name}'),
                    value: sponsor.isActive,
                    onChanged: (value) => _toggle(context, sponsor, value),
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}
