import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/blog/blog_repository.dart';
import '../../domain/blog/post.dart';

class SupabaseBlogRepository implements BlogRepository {
  const SupabaseBlogRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'post-images';

  @override
  Future<List<Post>> getClubPosts(String clubId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_club_posts',
      params: {'p_club_id': clubId},
    );
    return rows.cast<Map<String, dynamic>>().map(postFromRow).toList();
  });

  @override
  Future<String> savePost({
    String? postId,
    required String clubId,
    required String title,
    required String body,
    String? imagePath,
    required bool publish,
    DateTime? publishedAt,
  }) => _guard(
    () async => await _client.rpc<String>(
      'save_post',
      params: {
        'p_post_id': postId,
        'p_club_id': clubId,
        'p_title': title,
        'p_body': body,
        'p_image_path': imagePath,
        'p_publish': publish,
        'p_published_at': publishedAt?.toUtc().toIso8601String(),
      },
    ),
  );

  @override
  Future<void> setStatus(String postId, PostStatus status) => _guard(
    () => _client.rpc<void>(
      'set_post_status',
      params: {'p_post_id': postId, 'p_status': status.name},
    ),
  );

  @override
  Future<String> uploadImage({
    required String clubId,
    required Uint8List bytes,
    required String contentType,
  }) => _guard(() async {
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        '$clubId/post-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  });

  static const _columns = 'id, title, body, image_path, status, published_at';

  @override
  Future<PostsPage> getFeed(
    String clubId, {
    int offset = 0,
    int limit = 10,
  }) => _guard(() async {
    // RLS keeps out drafts, scheduled posts and other clubs; the filters make
    // the admin see the same feed as their members.
    final rows = await _client
        .from('posts')
        .select(_columns)
        .eq('club_id', clubId)
        .eq('status', 'published')
        .lte('published_at', DateTime.now().toUtc().toIso8601String())
        .order('published_at', ascending: false)
        .range(offset, offset + limit);
    final posts = rows
        .map((row) => postFromRow({...row, 'visible': true}))
        .toList();
    return PostsPage(
      posts: posts.take(limit).toList(),
      hasMore: posts.length > limit,
    );
  });

  @override
  Future<Post?> getPost(String postId) => _guard(() async {
    final row = await _client
        .from('posts')
        .select(_columns)
        .eq('id', postId)
        .eq('status', 'published')
        .maybeSingle();
    return row == null ? null : postFromRow({...row, 'visible': true});
  });

  @override
  Future<String?> imageUrl(String path) async {
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapBlogError(error.code, error.message);
    } on StorageException catch (error) {
      throw mapBlogError(error.statusCode, error.message);
    } on BlogFailure {
      rethrow;
    } catch (error) {
      throw BlogUnavailableFailure(error);
    }
  }
}

Post postFromRow(Map<String, dynamic> row) => Post(
  id: row['id'] as String,
  title: row['title'] as String,
  body: row['body'] as String,
  imagePath: row['image_path'] as String?,
  status: PostStatus.values.byName(row['status'] as String),
  publishedAt: switch (row['published_at']) {
    final String value => DateTime.parse(value),
    _ => null,
  },
  visible: row['visible'] == true,
);

BlogFailure mapBlogError(String? code, String message) => switch (code) {
  '42501' || '403' => const BlogPermissionFailure(),
  'P0002' => const PostNotFoundFailure(),
  '22023' when message.contains('title') => const InvalidPostFailure(
    PostField.title,
  ),
  '22023' when message.contains('image') => const InvalidPostFailure(
    PostField.image,
  ),
  '22023' => const InvalidPostFailure(PostField.body),
  '413' => const InvalidPostFailure(PostField.image),
  _ => BlogUnavailableFailure('$code $message'),
};
