import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/season/season.dart';
import '../../domain/sponsor/sponsor.dart';
import '../common/submit_dialog.dart';
import 'sponsor_widgets.dart';
import 'sponsors_view_model.dart';

/// New or edit sponsor: name, website, logo and seasons (RF-026, RF-027).
class SponsorDialog extends StatefulWidget {
  const SponsorDialog({super.key, required this.viewModel, this.sponsor});

  final SponsorsViewModel viewModel;
  final Sponsor? sponsor;

  @override
  State<SponsorDialog> createState() => _SponsorDialogState();
}

class _SponsorDialogState extends State<SponsorDialog> {
  late final _name = TextEditingController(text: widget.sponsor?.name ?? '');
  late final _website = TextEditingController(
    text: widget.sponsor?.websiteUrl ?? 'https://',
  );
  late String? _logoPath = widget.sponsor?.logoPath;
  Uint8List? _logoBytes;
  String? _logoError;
  late final Set<String> _seasonIds = {
    ...?widget.sponsor?.seasonIds,
    if (widget.sponsor == null && widget.viewModel.activeSeason != null)
      widget.viewModel.activeSeason!.id,
  };

  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _chooseLogo(VoidCallback refresh) async {
    try {
      final logo = await widget.viewModel.chooseLogo();
      if (logo == null) return;
      _logoPath = logo.path;
      _logoBytes = logo.bytes;
      _logoError = null;
    } on String catch (message) {
      _logoError = message;
    }
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.sponsor;
    final seasons = widget.viewModel.seasons
        .where(
          (s) => s.status != SeasonStatus.closed || _seasonIds.contains(s.id),
        )
        .toList();
    return SubmitDialog(
      title: editing == null ? 'Nuevo patrocinador' : 'Editar ${editing.name}',
      action: editing == null ? 'Dar de alta' : 'Guardar',
      saveKey: const Key('sponsor-save'),
      onSubmit: () => widget.viewModel.save(
        sponsor: editing,
        name: _name.text,
        website: _website.text.trim() == 'https://' ? '' : _website.text,
        logoPath: _logoPath,
        seasonIds: _seasonIds.toList(),
      ),
      builder: (context, refresh) => [
        TextField(
          key: const Key('sponsor-name'),
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('sponsor-website'),
          controller: _website,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Web (opcional)',
            helperText: 'Debe empezar por https://',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_logoBytes != null)
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(4),
                color: Colors.white,
                child: Image.memory(
                  _logoBytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.image_outlined),
                ),
              )
            else if (editing != null)
              SponsorLogo(sponsor: editing)
            else
              const Icon(Icons.image_outlined, size: 40),
            const SizedBox(width: 12),
            OutlinedButton(
              key: const Key('sponsor-logo'),
              onPressed: () => _chooseLogo(refresh),
              child: Text(_logoPath == null ? 'Subir logo' : 'Cambiar logo'),
            ),
          ],
        ),
        if (_logoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _logoError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('Temporadas', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        if (seasons.isEmpty)
          const Text('Crea una temporada para asociar patrocinadores.')
        else
          Wrap(
            spacing: 8,
            children: [
              for (final season in seasons)
                FilterChip(
                  key: Key('sponsor-season-${season.name}'),
                  label: Text(season.name),
                  selected: _seasonIds.contains(season.id),
                  onSelected: (selected) {
                    selected
                        ? _seasonIds.add(season.id)
                        : _seasonIds.remove(season.id);
                    refresh();
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// «Renovar para la temporada activa» in bulk (RF-028).
class RenewSponsorsDialog extends StatefulWidget {
  const RenewSponsorsDialog({super.key, required this.viewModel});

  final SponsorsViewModel viewModel;

  @override
  State<RenewSponsorsDialog> createState() => _RenewSponsorsDialogState();
}

class _RenewSponsorsDialogState extends State<RenewSponsorsDialog> {
  late final Set<String> _selected = {
    for (final s in widget.viewModel.renewalCandidates) s.id,
  };

  @override
  Widget build(BuildContext context) {
    final season = widget.viewModel.activeSeason!;
    return SubmitDialog(
      title: 'Renovar para ${season.name}',
      action: 'Renovar',
      saveKey: const Key('sponsors-renew-save'),
      onSubmit: () => widget.viewModel.renew(_selected.toList()),
      builder: (context, refresh) => [
        Text(
          'Patrocinadores de la temporada anterior que todavía no están en '
          '${season.name}. Los que no renueves no se mostrarán a los socios.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final sponsor in widget.viewModel.renewalCandidates)
          CheckboxListTile(
            key: Key('renew-${sponsor.name}'),
            contentPadding: EdgeInsets.zero,
            value: _selected.contains(sponsor.id),
            onChanged: (value) {
              value == true
                  ? _selected.add(sponsor.id)
                  : _selected.remove(sponsor.id);
              refresh();
            },
            title: Text(sponsor.name),
          ),
      ],
    );
  }
}
