/// One sensitive operation, attributed to the real person (§17).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.asPlatformAdmin,
    required this.createdAt,
    this.clubId,
    this.clubName,
    this.actorEmail,
    this.payload = const {},
  });

  final int id;
  final String action;

  /// True when a platform admin acted on a club they do not administer.
  final bool asPlatformAdmin;
  final DateTime createdAt;
  final String? clubId;
  final String? clubName;
  final String? actorEmail;
  final Map<String, Object?> payload;
}
