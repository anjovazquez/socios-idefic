import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/blog/post.dart';
import '../club/image_picking.dart';
import 'blog_messages.dart';

enum PublishMode { now, scheduled }

/// Creates or edits a post (RF-022): title, text, optional image and
/// publication now or at a future date.
class PostEditorViewModel extends ChangeNotifier {
  PostEditorViewModel(
    this._useCases, {
    required this.clubId,
    required this.pickImage,
    this.postId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppUseCases _useCases;
  final String clubId;
  final String? postId;
  final PickImage pickImage;
  final DateTime Function() _clock;

  Post? _original;
  Post? get original => _original;

  String initialTitle = '';
  String initialBody = '';

  String? _imagePath;
  String? get imagePath => _imagePath;

  Uint8List? _imageBytes;

  /// A newly chosen image (preview before saving).
  Uint8List? get imageBytes => _imageBytes;

  String? _imageUrl;

  /// The stored image of an existing post.
  String? get imageUrl => _imageUrl;

  PublishMode _mode = PublishMode.now;
  PublishMode get mode => _mode;

  late DateTime _scheduledAt = _defaultSchedule();
  DateTime get scheduledAt => _scheduledAt;

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool get isEditing => postId != null;

  DateTime _defaultSchedule() {
    final tomorrow = _clock().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
  }

  Future<void> load() async {
    if (postId != null) {
      try {
        final posts = await _useCases.getClubPosts(clubId);
        _original = posts.where((p) => p.id == postId).firstOrNull;
      } catch (_) {
        _error = blogFailureMessage(const BlogUnavailableFailure());
      }
      final post = _original;
      if (post != null) {
        initialTitle = post.title;
        initialBody = post.body;
        _imagePath = post.imagePath;
        if (post.isScheduled) {
          _mode = PublishMode.scheduled;
          _scheduledAt = post.publishedAt!.toLocal();
        }
        if (post.imagePath != null) {
          _imageUrl = await _useCases.getPostImageUrl(post.imagePath!);
        }
      } else {
        _error ??= blogFailureMessage(const PostNotFoundFailure());
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void setMode(PublishMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void setScheduledAt(DateTime value) {
    _scheduledAt = value;
    notifyListeners();
  }

  Future<void> chooseImage() async {
    final picked = await pickImage();
    if (picked == null) return;
    await _run(() async {
      _imagePath = await _useCases.uploadPostImage(
        clubId: clubId,
        bytes: picked.bytes,
        contentType: picked.contentType,
      );
      _imageBytes = picked.bytes;
      _imageUrl = null;
    });
  }

  void removeImage() {
    _imagePath = null;
    _imageBytes = null;
    _imageUrl = null;
    notifyListeners();
  }

  /// Returns the confirmation, or null with [error] set.
  Future<String?> save({
    required String title,
    required String body,
    required bool publish,
  }) async {
    final wasPublished =
        _original?.status == PostStatus.published &&
        (_original?.visible ?? false);
    DateTime? publishedAt;
    if (publish) {
      publishedAt = switch (_mode) {
        PublishMode.scheduled => _scheduledAt,
        // Editing a visible post keeps its date; new ones are published now.
        PublishMode.now => wasPublished ? _original!.publishedAt : null,
      };
      if (_mode == PublishMode.scheduled && !_scheduledAt.isAfter(_clock())) {
        _error = 'Elige una fecha de publicación futura';
        notifyListeners();
        return null;
      }
    }
    final ok = await _run(
      () => _useCases.savePost(
        postId: postId,
        clubId: clubId,
        title: title,
        body: body,
        imagePath: _imagePath,
        publish: publish,
        publishedAt: publishedAt,
      ),
    );
    if (!ok) return null;
    if (!publish) return 'Borrador guardado';
    if (_mode == PublishMode.scheduled) {
      return 'Noticia programada para el ${formatDateTime(_scheduledAt)}';
    }
    return wasPublished ? 'Cambios publicados' : 'Noticia publicada';
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on BlogFailure catch (failure) {
      _error = blogFailureMessage(failure);
      return false;
    } catch (_) {
      _error = blogFailureMessage(const BlogUnavailableFailure());
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
