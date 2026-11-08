/// Remembers which club the user last entered on this device.
abstract interface class ActiveClubStore {
  Future<String?> read();

  Future<void> write(String clubId);

  Future<void> clear();
}
