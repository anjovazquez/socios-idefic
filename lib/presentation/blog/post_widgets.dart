import 'package:flutter/material.dart';

import '../../domain/blog/post.dart';
import '../format/money.dart';

/// Image of a post from a temporary (signed) URL; nothing while loading or
/// if it cannot be read.
class PostImage extends StatelessWidget {
  const PostImage({super.key, required this.url, this.height = 160});

  final Future<String?> url;
  final double height;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: url,
    builder: (context, snapshot) {
      final value = snapshot.data;
      if (value == null) return const SizedBox.shrink();
      return Image.network(
        value,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: 'Imagen de la noticia',
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      );
    },
  );
}

/// A news item in the member's home.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.imageUrl,
    required this.onOpen,
  });

  final Post post;
  final Future<String?> imageUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('feed-post-${post.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (post.imagePath != null) PostImage(url: imageUrl),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.publishedAt != null)
                    Text(
                      formatDate(post.publishedAt!.toLocal()),
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  Text(post.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(post.excerpt, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
