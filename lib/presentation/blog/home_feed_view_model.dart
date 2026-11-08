import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/blog/post.dart';
import 'blog_messages.dart';

/// News of the active club in the member's home (RF-023).
class HomeFeedViewModel extends ChangeNotifier {
  HomeFeedViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  List<Post> _posts = const [];
  List<Post> get posts => _posts;

  bool _hasMore = false;
  bool get hasMore => _hasMore;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _loaded = false;
  bool get loaded => _loaded;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() => _fetch(reset: true);

  Future<void> loadMore() =>
      _hasMore && !_isLoading ? _fetch(reset: false) : Future.value();

  Future<void> _fetch({required bool reset}) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final page = await _useCases.getClubFeed(
        clubId,
        offset: reset ? 0 : _posts.length,
      );
      _posts = reset ? page.posts : [..._posts, ...page.posts];
      _hasMore = page.hasMore;
    } on BlogFailure catch (failure) {
      _loadError = blogFailureMessage(failure);
    } catch (_) {
      _loadError = blogFailureMessage(const BlogUnavailableFailure());
    } finally {
      _isLoading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  Future<String?> imageUrl(Post post) => post.imagePath == null
      ? Future.value()
      : _useCases.getPostImageUrl(post.imagePath!);
}
