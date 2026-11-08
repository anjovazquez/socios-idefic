import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/club/active_club_store.dart';

class SharedPreferencesActiveClubStore implements ActiveClubStore {
  SharedPreferencesActiveClubStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'active_club_id';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(_key);

  @override
  Future<void> write(String clubId) => _preferences.setString(_key, clubId);

  @override
  Future<void> clear() => _preferences.remove(_key);
}
