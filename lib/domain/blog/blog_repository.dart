import 'dart:typed_data';

import 'post.dart';

abstract interface class BlogRepository {
  /// Admin: every post of the club, newest first.
  Future<List<Post>> getClubPosts(String clubId);

  /// Admin: creates ([postId] null) or edits; returns the post id.
  /// [publish] with a null [publishedAt] publishes now; a future date
  /// schedules it. Without [publish] it is a draft.
  Future<String> savePost({
    String? postId,
    required String clubId,
    required String title,
    required String body,
    String? imagePath,
    required bool publish,
    DateTime? publishedAt,
  });

  /// Admin: archive (withdraw) or back to draft.
  Future<void> setStatus(String postId, PostStatus status);

  /// Admin: stores an image of the club; returns its path.
  Future<String> uploadImage({
    required String clubId,
    required Uint8List bytes,
    required String contentType,
  });

  /// Member: published posts of the club whose date arrived, newest first.
  Future<PostsPage> getFeed(String clubId, {int offset = 0, int limit = 10});

  /// Member: one published post (null when not visible to them).
  Future<Post?> getPost(String postId);

  /// Temporary URL of a private post image (members of the club).
  Future<String?> imageUrl(String path);
}
