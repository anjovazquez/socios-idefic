import 'dart:typed_data';

import '../../domain/blog/blog_repository.dart';
import '../../domain/blog/post.dart';

class GetClubPosts {
  const GetClubPosts(this._repository);

  final BlogRepository _repository;

  Future<List<Post>> call(String clubId) => _repository.getClubPosts(clubId);
}

class SavePost {
  const SavePost(this._repository);

  final BlogRepository _repository;

  Future<String> call({
    String? postId,
    required String clubId,
    required String title,
    required String body,
    String? imagePath,
    required bool publish,
    DateTime? publishedAt,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.length < 3 || cleanTitle.length > 140) {
      throw const InvalidPostFailure(PostField.title);
    }
    if (body.trim().isEmpty || body.trim().length > 20000) {
      throw const InvalidPostFailure(PostField.body);
    }
    return _repository.savePost(
      postId: postId,
      clubId: clubId,
      title: cleanTitle,
      body: body.trim(),
      imagePath: imagePath,
      publish: publish,
      publishedAt: publishedAt,
    );
  }
}

class SetPostStatus {
  const SetPostStatus(this._repository);

  final BlogRepository _repository;

  Future<void> call(String postId, PostStatus status) {
    if (status == PostStatus.published) {
      throw const InvalidPostFailure(PostField.title);
    }
    return _repository.setStatus(postId, status);
  }
}

class UploadPostImage {
  const UploadPostImage(this._repository);

  final BlogRepository _repository;

  static const maxBytes = 3 * 1024 * 1024;

  Future<String> call({
    required String clubId,
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.length > maxBytes ||
        !const [
          'image/png',
          'image/jpeg',
          'image/webp',
        ].contains(contentType)) {
      throw const InvalidPostFailure(PostField.image);
    }
    return _repository.uploadImage(
      clubId: clubId,
      bytes: bytes,
      contentType: contentType,
    );
  }
}

class GetPostImageUrl {
  const GetPostImageUrl(this._repository);

  final BlogRepository _repository;

  Future<String?> call(String path) => _repository.imageUrl(path);
}
