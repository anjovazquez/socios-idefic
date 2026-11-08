import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../application/platform/platform_use_cases.dart';
import '../../domain/platform/audit_entry.dart';
import '../../domain/platform/platform_club.dart';
import '../../domain/platform/platform_failures.dart';
import 'platform_view_model.dart';

class AuditLogViewModel extends ChangeNotifier {
  AuditLogViewModel(this._useCases);

  final AppUseCases _useCases;

  List<AuditEntry> _entries = const [];
  List<AuditEntry> get entries => _entries;

  List<PlatformClub> _clubs = const [];
  List<PlatformClub> get clubs => _clubs;

  String? _clubId;
  String? get clubId => _clubId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = false;
  bool get hasMore => _hasMore;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    await _run(() async {
      final (clubs, entries) = await (
        _useCases.getPlatformClubs(),
        _useCases.getAuditLog(clubId: _clubId),
      ).wait;
      _clubs = clubs;
      _setPage(entries, append: false);
    });
  }

  Future<void> filterByClub(String? clubId) async {
    _clubId = clubId;
    await _run(() async {
      _setPage(await _useCases.getAuditLog(clubId: clubId), append: false);
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore || _entries.isEmpty) return;
    await _run(() async {
      _setPage(
        await _useCases.getAuditLog(
          clubId: _clubId,
          beforeId: _entries.last.id,
        ),
        append: true,
      );
    });
  }

  void _setPage(List<AuditEntry> page, {required bool append}) {
    _entries = append ? [..._entries, ...page] : page;
    _hasMore = page.length == GetAuditLog.pageSize;
  }

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on PlatformFailure catch (failure) {
      _error = PlatformViewModel.messageFor(failure);
    } catch (_) {
      _error = PlatformViewModel.messageFor(const PlatformUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
