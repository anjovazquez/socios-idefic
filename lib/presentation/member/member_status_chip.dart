import 'package:flutter/material.dart';

import '../../domain/member/club_member.dart';

/// Membership state with icon + text (never only color, DESIGN.md §2.2).
class MemberStatusChip extends StatelessWidget {
  const MemberStatusChip({super.key, required this.status});

  final MemberStatus status;

  static String label(MemberStatus status) => switch (status) {
    MemberStatus.invited => 'Invitado',
    MemberStatus.active => 'Activo',
    MemberStatus.inactive => 'Baja',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background) = switch (status) {
      MemberStatus.invited => (Icons.mail_outline, scheme.secondaryContainer),
      MemberStatus.active => (
        Icons.check_circle_outline,
        scheme.primaryContainer,
      ),
      MemberStatus.inactive => (Icons.block, scheme.surfaceContainerHighest),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label(status)),
      backgroundColor: background,
    );
  }
}
