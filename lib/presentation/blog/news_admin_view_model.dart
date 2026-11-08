import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/blog/post.dart';
import 'blog_messages.dart';

/// News of the club for its admin (RF-022, §16 Blog).
class NewsAdminViewModel extends ChangeNotifier {
  NewsAdminViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  List<Post> _posts = const [];
  List<Post> get posts => _posts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _posts = await _useCases.getClubPosts(clubId);
    } on BlogFailure catch (failure) {
      _loadError = blogFailureMessage(failure);
    } catch (_) {
      _loadError = blogFailureMessage(const BlogUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the confirmation, or throws the error message.
  Future<String> archive(Post post) async {
    await _guard(() => _useCases.setPostStatus(post.id, PostStatus.archived));
    await load();
    return '«${post.title}» archivada: los socios ya no la ven';
  }

  Future<String> backToDraft(Post post) async {
    await _guard(() => _useCases.setPostStatus(post.id, PostStatus.draft));
    await load();
    return '«${post.title}» vuelve a borrador';
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on BlogFailure catch (failure) {
      throw blogFailureMessage(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw blogFailureMessage(const BlogUnavailableFailure());
    }
  }
}
