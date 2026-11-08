import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/club/club_branding_repository.dart';
import '../payment/payment_instructions_section.dart';
import '../session/session_view_model.dart';
import '../theme/club_theme.dart';
import 'club_avatar.dart';
import 'club_settings_view_model.dart';
import 'image_picking.dart';

/// Club data and visual identity (§16 Configuración, §20).
class ClubSettingsPage extends StatelessWidget {
  const ClubSettingsPage({super.key});

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
      create: (context) => ClubSettingsViewModel(
        context.read<AppUseCases>(),
        clubId: club.id,
        pickImage: context.read<PickImage>(),
        onSaved: session.refreshClubs,
      )..load(),
      child: const _ClubSettingsView(),
    );
  }
}

class _ClubSettingsView extends StatelessWidget {
  const _ClubSettingsView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClubSettingsViewModel>();
    final draft = viewModel.draft;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del club'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      body: switch (draft) {
        null when viewModel.isLoading => const Center(
          child: CircularProgressIndicator(),
        ),
        null => Center(child: Text(viewModel.error ?? '')),
        _ => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Datos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('settings-name'),
              initialValue: draft.name,
              onChanged: viewModel.setName,
              decoration: const InputDecoration(labelText: 'Nombre visible'),
            ),
            const SizedBox(height: 24),
            Text('Colores', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _ColorField(
              fieldKey: const Key('settings-primary'),
              label: 'Color principal',
              value: viewModel.primaryText,
              onChanged: viewModel.setPrimaryText,
            ),
            const SizedBox(height: 16),
            _ColorField(
              fieldKey: const Key('settings-secondary'),
              label: 'Color secundario (opcional)',
              value: viewModel.secondaryText,
              onChanged: viewModel.setSecondaryText,
            ),
            const SizedBox(height: 24),
            Text('Logo e imagen', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _AssetRow(
              kind: ClubAssetKind.logo,
              label: 'Logo',
              preview: ClubAvatar(
                name: draft.name,
                logoUrl: draft.logoUrl,
                primaryColor: viewModel.previewPrimary,
              ),
              hasAsset: draft.logoUrl != null,
            ),
            const SizedBox(height: 8),
            _AssetRow(
              kind: ClubAssetKind.image,
              label: 'Imagen de portada',
              preview: SizedBox.square(
                dimension: 48,
                child: draft.imageUrl == null
                    ? const Icon(Icons.image_outlined)
                    : Image.network(draft.imageUrl!, fit: BoxFit.cover),
              ),
              hasAsset: draft.imageUrl != null,
            ),
            const SizedBox(height: 24),
            Text('Vista previa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _BrandPreview(
              name: draft.name,
              logoUrl: draft.logoUrl,
              primary: viewModel.previewPrimary,
              secondary: viewModel.previewSecondary,
            ),
            if (viewModel.error case final error?) ...[
              const SizedBox(height: 16),
              Text(
                error,
                key: const Key('settings-error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('settings-save'),
              // Saves name, colors and images (instructions save on their own).
              onPressed: viewModel.isBusy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (await viewModel.save()) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Cambios guardados')),
                        );
                      }
                    },
              child: const Text('Guardar cambios'),
            ),
            const SizedBox(height: 32),
            PaymentInstructionsSection(clubId: viewModel.clubId),
          ],
        ),
      },
    );
  }
}

class _ColorField extends StatefulWidget {
  const _ColorField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(widget.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: widget.fieldKey,
          controller: _controller,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: '#RRGGBB',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                radius: 10,
                backgroundColor:
                    color ?? Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in BrandTokens.presetColors)
              Semantics(
                button: true,
                label: '${widget.label} $hex',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onChanged(hex),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.outline,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: parseHexColor(hex),
                      child: widget.value.toUpperCase() == hex
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: readableOn(parseHexColor(hex)!),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.kind,
    required this.label,
    required this.preview,
    required this.hasAsset,
  });

  final ClubAssetKind kind;
  final String label;
  final Widget preview;
  final bool hasAsset;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ClubSettingsViewModel>();
    final busy = context.watch<ClubSettingsViewModel>().isBusy;
    return Row(
      children: [
        preview,
        const SizedBox(width: 16),
        Expanded(child: Text(label)),
        TextButton(
          key: Key('settings-upload-${kind.name}'),
          onPressed: busy ? null : () => viewModel.pickAsset(kind),
          child: Text(hasAsset ? 'Cambiar' : 'Subir'),
        ),
        if (hasAsset)
          IconButton(
            tooltip: 'Quitar ${label.toLowerCase()}',
            onPressed: busy ? null : () => viewModel.removeAsset(kind),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }
}

/// Header, avatar and main action as members will see them.
class _BrandPreview extends StatelessWidget {
  const _BrandPreview({
    required this.name,
    required this.logoUrl,
    required this.primary,
    required this.secondary,
  });

  final String name;
  final String? logoUrl;
  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final previewTheme = buildClubTheme(
      primaryHex: primary,
      secondaryHex: secondary,
    );
    final scheme = previewTheme.colorScheme;
    return Theme(
      data: previewTheme,
      child: Card(
        key: const Key('settings-preview'),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('settings-preview-header'),
              color: scheme.primary,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClubAvatar(
                    name: name,
                    logoUrl: logoUrl,
                    primaryColor: primary,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      key: const Key('settings-preview-title'),
                      style: previewTheme.textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Mi carnet'),
                  ),
                  const SizedBox(width: 8),
                  if (secondary != null)
                    Chip(
                      label: Text(
                        'Socio',
                        style: TextStyle(color: scheme.onSecondary),
                      ),
                      backgroundColor: scheme.secondary,
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
