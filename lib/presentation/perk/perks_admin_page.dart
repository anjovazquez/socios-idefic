import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/perk/perk.dart';
import '../session/session_view_model.dart';
import 'perk_labels.dart';

/// Perks of the club for its admin (RF-024).
class PerksAdminViewModel extends ChangeNotifier {
  PerksAdminViewModel(this._useCases, {required this.clubId, DateTime? today})
    : today = today ?? DateTime.now();

  final AppUseCases _useCases;
  final String clubId;
  final DateTime today;

  List<Perk> _perks = const [];
  List<Perk> get perks => _perks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _perks = await _useCases.getClubPerks(clubId);
    } on PerkFailure catch (failure) {
      _loadError = perkFailureMessage(failure);
    } catch (_) {
      _loadError = perkFailureMessage(const PerkUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> setStatus(Perk perk, PerkStatus status) async {
    try {
      await _useCases.setPerkStatus(perk.id, status);
    } on PerkFailure catch (failure) {
      throw perkFailureMessage(failure);
    } catch (_) {
      throw perkFailureMessage(const PerkUnavailableFailure());
    }
    await load();
    return status == PerkStatus.archived
        ? '«${perk.title}» archivada: los socios ya no la ven'
        : '«${perk.title}» vuelve a borrador';
  }
}

class PerksAdminPage extends StatelessWidget {
  const PerksAdminPage({super.key});

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
      create: (context) =>
          PerksAdminViewModel(context.read<AppUseCases>(), clubId: club.id)
            ..load(),
      child: const _PerksAdminView(),
    );
  }
}

class _PerksAdminView extends StatelessWidget {
  const _PerksAdminView();

  Future<void> _openEditor(BuildContext context, [String? perkId]) async {
    final viewModel = context.read<PerksAdminViewModel>();
    await context.push(
      Uri(
        path: '/club/perks/edit',
        queryParameters: perkId == null ? null : {'id': perkId},
      ).toString(),
    );
    await viewModel.load();
  }

  Future<void> _setStatus(
    BuildContext context,
    Perk perk,
    PerkStatus status,
  ) async {
    final viewModel = context.read<PerksAdminViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = await viewModel.setStatus(perk, status);
    } on String catch (error) {
      message = error;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PerksAdminViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventajas'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-perk'),
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.local_offer_outlined),
        label: const Text('Nueva ventaja'),
      ),
      body: switch (viewModel) {
        PerksAdminViewModel(isLoading: true, perks: []) => const Center(
          child: CircularProgressIndicator(),
        ),
        PerksAdminViewModel(:final loadError?) => Center(
          child: Text(loadError),
        ),
        PerksAdminViewModel(perks: []) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Todavía no hay ventajas. Publica la primera: por ejemplo, un '
              'descuento de un patrocinador presentando el carnet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            for (final perk in viewModel.perks)
              Card(
                key: Key('perk-${perk.title}'),
                child: ListTile(
                  onTap: () => _openEditor(context, perk.id),
                  title: Text(perk.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (perk.sponsorName != null)
                        Text('Patrocinador: ${perk.sponsorName}'),
                      Text(perkValidity(perk)),
                      const SizedBox(height: 4),
                      PerkStatusChip(perk: perk, today: viewModel.today),
                    ],
                  ),
                  trailing: PopupMenuButton<PerkStatus>(
                    key: Key('perk-menu-${perk.title}'),
                    onSelected: (status) => _setStatus(context, perk, status),
                    itemBuilder: (context) => [
                      if (perk.status != PerkStatus.archived)
                        const PopupMenuItem(
                          value: PerkStatus.archived,
                          child: Text('Archivar (retirar)'),
                        ),
                      if (perk.status != PerkStatus.draft)
                        const PopupMenuItem(
                          value: PerkStatus.draft,
                          child: Text('Pasar a borrador'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}
