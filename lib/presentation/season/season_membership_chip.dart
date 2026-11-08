import 'package:flutter/material.dart';

import '../../domain/season/season_membership.dart';

/// Condition in a season with icon + text (DESIGN.md §2.2).
class SeasonMembershipChip extends StatelessWidget {
  const SeasonMembershipChip({super.key, required this.status});

  final SeasonMembershipStatus status;

  static String label(SeasonMembershipStatus status) => switch (status) {
    SeasonMembershipStatus.active => 'Socio',
    SeasonMembershipStatus.pendingPayment => 'Pendiente de pago',
    SeasonMembershipStatus.notRenewed => 'No renovado',
    SeasonMembershipStatus.cancelled => 'Cancelado',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background) = switch (status) {
      SeasonMembershipStatus.active => (
        Icons.verified_outlined,
        scheme.primaryContainer,
      ),
      SeasonMembershipStatus.pendingPayment => (
        Icons.schedule,
        scheme.tertiaryContainer,
      ),
      SeasonMembershipStatus.notRenewed => (
        Icons.remove_circle_outline,
        scheme.surfaceContainerHighest,
      ),
      SeasonMembershipStatus.cancelled => (
        Icons.cancel_outlined,
        scheme.surfaceContainerHighest,
      ),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label(status)),
      backgroundColor: background,
    );
  }
}
