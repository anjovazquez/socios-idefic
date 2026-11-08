import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/season/season.dart';
import '../format/money.dart';
import '../session/session_view_model.dart';
import 'season_dialogs.dart';
import 'seasons_view_model.dart';

/// Seasons of the club for its administration (§16 Temporadas).
class SeasonsPage extends StatelessWidget {
  const SeasonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionViewModel>();
    final club = session.activeClub;
    if (club == null || !club.canAdminister) {
      return const Scaffold(
        body: Center(
          child: Text('Solo el administrador del club puede ver esta pantalla'),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (context) => SeasonsViewModel(
        context.read<AppUseCases>(),
        clubId: club.id,
        onChanged: session.refreshClubs,
      )..load(),
      child: const _SeasonsView(),
    );
  }
}

class _SeasonsView extends StatelessWidget {
  const _SeasonsView();

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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SeasonsViewModel>();
    final theme = Theme.of(context);
    final active = viewModel.active;
    final others = viewModel.seasons.where((s) => s != active).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temporadas'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-season'),
        onPressed: () => _show(
          context,
          NewSeasonDialog(
            suggestedName: viewModel.suggestedName,
            onSubmit: (name) => viewModel.create(name: name),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva temporada'),
      ),
      body: switch (viewModel) {
        SeasonsViewModel(isLoading: true, seasons: []) => const Center(
          child: CircularProgressIndicator(),
        ),
        SeasonsViewModel(:final loadError?) => Center(child: Text(loadError)),
        SeasonsViewModel(seasons: []) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Todavía no hay temporadas. Crea la primera y actívala con su '
              'cuota.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('Temporada activa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (active == null)
              const Text('Ninguna. Activa una temporada para empezar.')
            else
              _SeasonCard(
                season: active,
                onActivate: () => _show(
                  context,
                  ActivateSeasonDialog(
                    season: active,
                    currentActive: active,
                    onSubmit: (fee) => viewModel.activate(active, fee),
                  ),
                ),
              ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Otras temporadas', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final season in others)
                _SeasonCard(
                  season: season,
                  onActivate: season.status == SeasonStatus.draft
                      ? () => _show(
                          context,
                          ActivateSeasonDialog(
                            season: season,
                            currentActive: active,
                            onSubmit: (fee) => viewModel.activate(season, fee),
                          ),
                        )
                      : null,
                ),
            ],
          ],
        ),
      },
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season, required this.onActivate});

  final Season season;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (label, icon, background) = switch (season.status) {
      SeasonStatus.active => (
        'Activa',
        Icons.play_circle_outline,
        scheme.primaryContainer,
      ),
      SeasonStatus.draft => (
        'Preparada',
        Icons.edit_calendar_outlined,
        scheme.secondaryContainer,
      ),
      SeasonStatus.closed => (
        'Cerrada',
        Icons.history,
        scheme.surfaceContainerHighest,
      ),
    };
    final fee = season.defaultFeeCents;
    return Card(
      key: Key('season-${season.name}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(season.name, style: theme.textTheme.titleLarge),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  backgroundColor: background,
                ),
              ],
            ),
            Text(
              '${formatDate(season.startsOn)} – ${formatDate(season.endsOn)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              fee == null ? 'Cuota sin fijar' : 'Cuota: ${formatCents(fee)}',
              style: theme.textTheme.bodyLarge,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  if (season.status != SeasonStatus.closed)
                    TextButton(
                      key: Key('season-renew-${season.name}'),
                      onPressed: () => context.go(
                        Uri(
                          path: '/club/seasons/renew',
                          queryParameters: {
                            'season': season.id,
                            'name': season.name,
                          },
                        ).toString(),
                      ),
                      child: const Text('Renovar socios'),
                    ),
                  if (onActivate != null)
                    TextButton(
                      key: Key('season-action-${season.name}'),
                      onPressed: onActivate,
                      child: Text(
                        season.status == SeasonStatus.active
                            ? 'Cambiar cuota'
                            : 'Activar',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
