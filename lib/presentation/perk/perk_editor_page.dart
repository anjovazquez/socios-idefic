import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/blog/post.dart';
import '../../domain/perk/perk.dart';
import '../../domain/sponsor/sponsor.dart';
import '../blog/blog_messages.dart';
import '../club/image_picking.dart';
import '../format/money.dart';
import '../session/session_view_model.dart';
import 'perk_labels.dart';

/// Creates or edits a perk (RF-024).
class PerkEditorViewModel extends ChangeNotifier {
  PerkEditorViewModel(
    this._useCases, {
    required this.clubId,
    required this.pickImage,
    this.perkId,
  });

  final AppUseCases _useCases;
  final String clubId;
  final String? perkId;
  final PickImage pickImage;

  Perk? _original;
  String initialTitle = '';
  String initialBody = '';

  List<Sponsor> _sponsors = const [];
  List<Sponsor> get sponsors => _sponsors;

  String? _sponsorId;
  String? get sponsorId => _sponsorId;

  String? _imagePath;
  String? get imagePath => _imagePath;
  Uint8List? _imageBytes;
  Uint8List? get imageBytes => _imageBytes;

  DateTime? _validFrom;
  DateTime? get validFrom => _validFrom;
  DateTime? _validUntil;
  DateTime? get validUntil => _validUntil;

  bool _loaded = false;
  bool get loaded => _loaded;
  bool _busy = false;
  bool get busy => _busy;
  String? _error;
  String? get error => _error;

  bool get isEditing => perkId != null;

  Future<void> load() async {
    try {
      _sponsors = await _useCases.getClubSponsors(clubId);
    } catch (_) {
      _sponsors = const [];
    }
    if (perkId != null) {
      try {
        final perks = await _useCases.getClubPerks(clubId);
        _original = perks.where((p) => p.id == perkId).firstOrNull;
      } catch (_) {}
      final perk = _original;
      if (perk == null) {
        _error = 'Esta ventaja ya no existe';
      } else {
        initialTitle = perk.title;
        initialBody = perk.body;
        _sponsorId = perk.sponsorId;
        _imagePath = perk.imagePath;
        _validFrom = perk.validFrom;
        _validUntil = perk.validUntil;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void setSponsor(String? id) {
    _sponsorId = id;
    notifyListeners();
  }

  void setValidFrom(DateTime? value) {
    _validFrom = value;
    notifyListeners();
  }

  void setValidUntil(DateTime? value) {
    _validUntil = value;
    notifyListeners();
  }

  Future<void> chooseImage() async {
    final picked = await pickImage();
    if (picked == null) return;
    await _run(() async {
      _imagePath = await _useCases.uploadPostImage(
        clubId: clubId,
        bytes: picked.bytes,
        contentType: picked.contentType,
      );
      _imageBytes = picked.bytes;
    });
  }

  void removeImage() {
    _imagePath = null;
    _imageBytes = null;
    notifyListeners();
  }

  /// Returns the confirmation, or null with [error] set.
  Future<String?> save({
    required String title,
    required String body,
    required bool publish,
  }) async {
    final ok = await _run(
      () => _useCases.savePerk(
        perkId: perkId,
        clubId: clubId,
        sponsorId: _sponsorId,
        title: title,
        body: body,
        imagePath: _imagePath,
        validFrom: _validFrom,
        validUntil: _validUntil,
        publish: publish,
      ),
    );
    if (!ok) return null;
    return publish ? 'Ventaja publicada' : 'Borrador guardado';
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on PerkFailure catch (failure) {
      _error = perkFailureMessage(failure);
    } on BlogFailure catch (failure) {
      _error = blogFailureMessage(failure);
    } catch (_) {
      _error = perkFailureMessage(const PerkUnavailableFailure());
    } finally {
      _busy = false;
      notifyListeners();
    }
    return false;
  }
}

class PerkEditorPage extends StatelessWidget {
  const PerkEditorPage({super.key, this.perkId});

  final String? perkId;

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
      create: (context) => PerkEditorViewModel(
        context.read<AppUseCases>(),
        clubId: club.id,
        perkId: perkId,
        pickImage: context.read<PickImage>(),
      )..load(),
      child: const _PerkEditorView(),
    );
  }
}

class _PerkEditorView extends StatefulWidget {
  const _PerkEditorView();

  @override
  State<_PerkEditorView> createState() => _PerkEditorViewState();
}

class _PerkEditorViewState extends State<_PerkEditorView> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _close(GoRouter router) =>
      router.canPop() ? router.pop() : router.go('/club/perks');

  Future<void> _pickDate(
    DateTime? current,
    void Function(DateTime?) onPicked,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save(
    PerkEditorViewModel viewModel, {
    required bool publish,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final message = await viewModel.save(
      title: _title.text,
      body: _body.text,
      publish: publish,
    );
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    _close(router);
  }

  Widget _dateTile({
    required Key key,
    required String label,
    required DateTime? value,
    required String empty,
    required void Function(DateTime?) onChanged,
  }) => ListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.event),
    title: Text(label),
    subtitle: Text(value == null ? empty : formatDate(value)),
    onTap: () => _pickDate(value, onChanged),
    trailing: value == null
        ? const Text('Elegir')
        : IconButton(
            tooltip: 'Quitar fecha',
            icon: const Icon(Icons.clear),
            onPressed: () => onChanged(null),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PerkEditorViewModel>();
    final theme = Theme.of(context);
    if (viewModel.loaded && !_filled) {
      _title.text = viewModel.initialTitle;
      _body.text = viewModel.initialBody;
      _filled = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Editar ventaja' : 'Nueva ventaja'),
        leading: BackButton(onPressed: () => _close(GoRouter.of(context))),
      ),
      body: !viewModel.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const Key('perk-title'),
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: '10 % de descuento en Restaurante X',
                  ),
                ),
                TextField(
                  key: const Key('perk-body'),
                  controller: _body,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Cómo se consigue',
                    alignLabelWithHint: true,
                    hintText: 'Presentando tu carnet de socio…',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  key: const Key('perk-sponsor'),
                  initialValue: viewModel.sponsorId,
                  decoration: const InputDecoration(
                    labelText: 'Patrocinador (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Ninguno (ventaja del club)'),
                    ),
                    for (final sponsor in viewModel.sponsors)
                      DropdownMenuItem(
                        value: sponsor.id,
                        child: Text(sponsor.name),
                      ),
                  ],
                  onChanged: viewModel.setSponsor,
                ),
                const SizedBox(height: 16),
                Text('Vigencia', style: theme.textTheme.titleSmall),
                _dateTile(
                  key: const Key('perk-valid-from'),
                  label: 'Desde',
                  value: viewModel.validFrom,
                  empty: 'Desde ya',
                  onChanged: viewModel.setValidFrom,
                ),
                _dateTile(
                  key: const Key('perk-valid-until'),
                  label: 'Hasta',
                  value: viewModel.validUntil,
                  empty: 'Sin fecha de fin',
                  onChanged: viewModel.setValidUntil,
                ),
                const SizedBox(height: 8),
                Text('Imagen (opcional)', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (viewModel.imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      viewModel.imageBytes!,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  )
                else if (viewModel.imagePath != null)
                  const ListTile(
                    leading: Icon(Icons.image_outlined),
                    title: Text('Imagen añadida'),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('perk-image-pick'),
                      onPressed: viewModel.busy ? null : viewModel.chooseImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        viewModel.imagePath == null
                            ? 'Añadir imagen'
                            : 'Cambiar imagen',
                      ),
                    ),
                    if (viewModel.imagePath != null)
                      TextButton(
                        onPressed: viewModel.removeImage,
                        child: const Text('Quitar imagen'),
                      ),
                  ],
                ),
                if (viewModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      viewModel.error!,
                      key: const Key('perk-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('perk-save-draft'),
                      onPressed: viewModel.busy
                          ? null
                          : () => _save(viewModel, publish: false),
                      child: const Text('Guardar borrador'),
                    ),
                    FilledButton(
                      key: const Key('perk-publish'),
                      onPressed: viewModel.busy
                          ? null
                          : () => _save(viewModel, publish: true),
                      child: const Text('Publicar'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
