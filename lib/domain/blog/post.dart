/// A news post of a club for its members (RF-022).
enum PostStatus { draft, published, archived }

class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    this.imagePath,
    this.publishedAt,
    this.visible = false,
  });

  final String id;
  final String title;

  /// Simple text; paragraphs separated by blank lines.
  final String body;
  final String? imagePath;
  final PostStatus status;
  final DateTime? publishedAt;

  /// Published and its date arrived: members can read it.
  final bool visible;

  /// First paragraph, shortened for lists.
  String get excerpt {
    final first = body.split(RegExp(r'\n\s*\n')).first.trim();
    return first.length <= 160
        ? first
        : '${first.substring(0, 157).trimRight()}…';
  }

  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  bool get isScheduled =>
      status == PostStatus.published && !visible && publishedAt != null;
}

enum PostField { title, body, image }

sealed class BlogFailure implements Exception {
  const BlogFailure();
}

final class InvalidPostFailure extends BlogFailure {
  const InvalidPostFailure(this.field);

  final PostField field;
}

final class PostNotFoundFailure extends BlogFailure {
  const PostNotFoundFailure();
}

final class BlogPermissionFailure extends BlogFailure {
  const BlogPermissionFailure();
}

final class BlogUnavailableFailure extends BlogFailure {
  const BlogUnavailableFailure([this.cause]);

  final Object? cause;
}

/// A page of the members' news feed.
class PostsPage {
  const PostsPage({required this.posts, required this.hasMore});

  final List<Post> posts;
  final bool hasMore;
}
