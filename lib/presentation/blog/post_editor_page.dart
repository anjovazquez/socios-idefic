import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../club/image_picking.dart';
import '../session/session_view_model.dart';
import 'blog_messages.dart';
import 'post_editor_view_model.dart';

/// Editor of a news post (RF-022).
class PostEditorPage extends StatelessWidget {
  const PostEditorPage({super.key, this.postId});

  final String? postId;

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
      create: (context) => PostEditorViewModel(
        context.read<AppUseCases>(),
        clubId: club.id,
        postId: postId,
        pickImage: context.read<PickImage>(),
      )..load(),
      child: const _PostEditorView(),
    );
  }
}

class _PostEditorView extends StatefulWidget {
  const _PostEditorView();

  @override
  State<_PostEditorView> createState() => _PostEditorViewState();
}

class _PostEditorViewState extends State<_PostEditorView> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule(PostEditorViewModel viewModel) async {
    final current = viewModel.scheduledAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    viewModel.setScheduledAt(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _save(
    PostEditorViewModel viewModel, {
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

  void _close(GoRouter router) =>
      router.canPop() ? router.pop() : router.go('/club/news');

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostEditorViewModel>();
    final theme = Theme.of(context);
    if (viewModel.loaded && !_filled) {
      _title.text = viewModel.initialTitle;
      _body.text = viewModel.initialBody;
      _filled = true;
    }
    final scheduled = viewModel.mode == PublishMode.scheduled;
    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Editar noticia' : 'Nueva noticia'),
        leading: BackButton(onPressed: () => _close(GoRouter.of(context))),
      ),
      body: !viewModel.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const Key('post-title'),
                  controller: _title,
                  maxLength: 140,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                TextField(
                  key: const Key('post-body'),
                  controller: _body,
                  minLines: 6,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: 'Texto',
                    alignLabelWithHint: true,
                    helperText: 'Separa los párrafos con una línea en blanco',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Imagen (opcional)', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (viewModel.imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      viewModel.imageBytes!,
                      key: const Key('post-image-preview'),
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (viewModel.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      viewModel.imageUrl!,
                      key: const Key('post-image-preview'),
                      height: 180,
                      fit: BoxFit.cover,
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
                      key: const Key('post-image-pick'),
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
                        key: const Key('post-image-remove'),
                        onPressed: viewModel.removeImage,
                        child: const Text('Quitar imagen'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Publicación', style: theme.textTheme.titleSmall),
                SegmentedButton<PublishMode>(
                  key: const Key('post-publish-mode'),
                  segments: const [
                    ButtonSegment(
                      value: PublishMode.now,
                      label: Text('Ahora'),
                      icon: Icon(Icons.public),
                    ),
                    ButtonSegment(
                      value: PublishMode.scheduled,
                      label: Text('Programar'),
                      icon: Icon(Icons.schedule),
                    ),
                  ],
                  selected: {viewModel.mode},
                  onSelectionChanged: (value) => viewModel.setMode(value.first),
                ),
                if (scheduled)
                  ListTile(
                    key: const Key('post-schedule'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(
                      'Se publicará el ${formatDateTime(viewModel.scheduledAt)}',
                    ),
                    trailing: const Text('Cambiar'),
                    onTap: () => _pickSchedule(viewModel),
                  ),
                if (viewModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      viewModel.error!,
                      key: const Key('post-error'),
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
                      key: const Key('post-save-draft'),
                      onPressed: viewModel.busy
                          ? null
                          : () => _save(viewModel, publish: false),
                      child: const Text('Guardar borrador'),
                    ),
                    FilledButton(
                      key: const Key('post-publish'),
                      onPressed: viewModel.busy
                          ? null
                          : () => _save(viewModel, publish: true),
                      child: Text(scheduled ? 'Programar' : 'Publicar'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
