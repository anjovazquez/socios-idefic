import 'package:flutter/material.dart';

import '../../domain/blog/post.dart';
import '../format/money.dart';

String blogFailureMessage(BlogFailure failure) => switch (failure) {
  InvalidPostFailure(field: PostField.title) =>
    'El título debe tener entre 3 y 140 caracteres',
  InvalidPostFailure(field: PostField.body) => 'Escribe el texto de la noticia',
  InvalidPostFailure(field: PostField.image) =>
    'La imagen debe ser PNG, JPG o WebP de 3 MB como máximo',
  PostNotFoundFailure() => 'Esta noticia ya no existe',
  BlogPermissionFailure() =>
    'Solo el administrador del club puede publicar noticias',
  BlogUnavailableFailure() =>
    'No hemos podido conectar. Inténtalo de nuevo en un momento',
};

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${formatDate(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// State of a post with icon + text (DESIGN.md §2.2).
class PostStatusChip extends StatelessWidget {
  const PostStatusChip({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, background) = switch (post) {
      Post(status: PostStatus.published, visible: true) => (
        'Publicada',
        Icons.public,
        scheme.primaryContainer,
      ),
      Post(status: PostStatus.published) => (
        'Programada',
        Icons.schedule,
        scheme.tertiaryContainer,
      ),
      Post(status: PostStatus.draft) => (
        'Borrador',
        Icons.edit_note,
        scheme.secondaryContainer,
      ),
      Post(status: PostStatus.archived) => (
        'Archivada',
        Icons.inventory_2_outlined,
        scheme.surfaceContainerHighest,
      ),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: background,
    );
  }
}
