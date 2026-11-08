import '../../domain/platform/audit_entry.dart';

/// Human wording for audit actions. Unknown actions show their code.
String auditActionLabel(String action) => switch (action) {
  'club_created' => 'Club creado',
  'club_updated' => 'Club editado',
  'club_activated' => 'Club activado',
  'club_deactivated' => 'Club desactivado',
  'club_admin_assigned' => 'Administrador asignado',
  'club_admin_invited' => 'Administrador invitado',
  'club_branding_updated' => 'Identidad visual cambiada',
  _ => action,
};

/// Short detail from the payload (name, email or code), if any.
String? auditDetail(AuditEntry entry) {
  for (final key in ['email', 'name', 'code']) {
    final value = entry.payload[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// `dd/MM/yyyy HH:mm` in the device time zone.
String formatAuditDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
