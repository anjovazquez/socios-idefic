import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/blog/post.dart';
import '../session/session_view_model.dart';
import 'blog_messages.dart';
import 'news_admin_view_model.dart';

/// News of the club for its admin (RF-022, §16 Blog).
class NewsAdminPage extends StatelessWidget {
  const NewsAdminPage({super.key});

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
          NewsAdminViewModel(context.read<AppUseCases>(), clubId: club.id)
            ..load(),
      child: const _NewsAdminView(),
    );
  }
}

class _NewsAdminView extends StatelessWidget {
  const _NewsAdminView();

  Future<void> _act(
    BuildContext context,
    Future<String> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      message = await action();
    } on String catch (error) {
      message = error;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The editor returns here; the list reloads to show the changes.
  Future<void> _openEditor(BuildContext context, [String? postId]) async {
    final viewModel = context.read<NewsAdminViewModel>();
    await context.push(
      Uri(
        path: '/club/news/edit',
        queryParameters: postId == null ? null : {'id': postId},
      ).toString(),
    );
    await viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NewsAdminViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noticias'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-post'),
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Nueva noticia'),
      ),
      body: switch (viewModel) {
        NewsAdminViewModel(isLoading: true, posts: []) => const Center(
          child: CircularProgressIndicator(),
        ),
        NewsAdminViewModel(:final loadError?) => Center(child: Text(loadError)),
        NewsAdminViewModel(posts: []) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Todavía no hay noticias. Publica la primera para tus socios.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final post in viewModel.posts)
                Card(
                  key: Key('post-${post.title}'),
                  child: ListTile(
                    onTap: () => _openEditor(context, post.id),
                    title: Text(post.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post.publishedAt != null)
                          Text(formatDateTime(post.publishedAt!)),
                        const SizedBox(height: 4),
                        PostStatusChip(post: post),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      key: Key('post-menu-${post.title}'),
                      onSelected: (value) => _act(
                        context,
                        () => value == 'archive'
                            ? viewModel.archive(post)
                            : viewModel.backToDraft(post),
                      ),
                      itemBuilder: (context) => [
                        if (post.status != PostStatus.archived)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Archivar (retirar)'),
                          ),
                        if (post.status != PostStatus.draft)
                          const PopupMenuItem(
                            value: 'draft',
                            child: Text('Pasar a borrador'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      },
    );
  }
}
