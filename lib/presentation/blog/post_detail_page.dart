import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/blog/post.dart';
import '../format/money.dart';
import 'post_widgets.dart';

/// A news post for the members of the club (RF-023).
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final Future<Post?> _post = context.read<AppUseCases>().getPost(
    widget.postId,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noticia'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/club'),
        ),
      ),
      body: FutureBuilder<Post?>(
        future: _post,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = snapshot.data;
          if (post == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Esta noticia ya no está disponible.',
                  key: Key('post-unavailable'),
                ),
              ),
            );
          }
          return ListView(
            children: [
              if (post.imagePath != null)
                PostImage(
                  url: context.read<AppUseCases>().getPostImageUrl(
                    post.imagePath!,
                  ),
                  height: 220,
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.publishedAt != null)
                      Text(
                        formatLongDate(post.publishedAt!.toLocal()),
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      post.title,
                      key: const Key('post-detail-title'),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    for (final paragraph in post.paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          paragraph,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
