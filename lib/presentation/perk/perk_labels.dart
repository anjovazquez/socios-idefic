import 'package:flutter/material.dart';

import '../../domain/perk/perk.dart';
import '../format/money.dart';

String perkFailureMessage(PerkFailure failure) => switch (failure) {
  InvalidPerkFailure(field: PerkField.title) =>
    'El título debe tener entre 3 y 120 caracteres',
  InvalidPerkFailure(field: PerkField.body) =>
    'Explica la ventaja y cómo se consigue',
  InvalidPerkFailure(field: PerkField.dates) =>
    'La fecha de fin no puede ser anterior a la de inicio',
  InvalidPerkFailure(field: PerkField.sponsor) =>
    'Elige un patrocinador de este club',
  InvalidPerkFailure(field: PerkField.image) =>
    'La imagen debe ser PNG, JPG o WebP de 3 MB como máximo',
  PerkPermissionFailure() =>
    'Solo el administrador del club puede gestionar ventajas',
  PerkUnavailableFailure() =>
    'No hemos podido conectar. Inténtalo de nuevo en un momento',
};

/// «Del 01/12/2026 al 31/12/2026», «Hasta el 31/12/2026», «Sin fecha de fin».
String perkValidity(Perk perk) => switch ((perk.validFrom, perk.validUntil)) {
  (final from?, final until?) =>
    'Del ${formatDate(from)} al ${formatDate(until)}',
  (final from?, null) => 'Desde el ${formatDate(from)}',
  (null, final until?) => 'Hasta el ${formatDate(until)}',
  (null, null) => 'Sin fecha de fin',
};

/// What members see today, with icon + text (DESIGN.md §2.2).
class PerkStatusChip extends StatelessWidget {
  const PerkStatusChip({super.key, required this.perk, required this.today});

  final Perk perk;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, background) = switch (perk.visibilityOn(today)) {
      PerkVisibility.visible => (
        'Vigente',
        Icons.check_circle_outline,
        scheme.primaryContainer,
      ),
      PerkVisibility.upcoming => (
        'Próximamente',
        Icons.schedule,
        scheme.tertiaryContainer,
      ),
      PerkVisibility.expired => (
        'Caducada',
        Icons.event_busy,
        scheme.surfaceContainerHighest,
      ),
      PerkVisibility.draft => (
        'Borrador',
        Icons.edit_note,
        scheme.secondaryContainer,
      ),
      PerkVisibility.archived => (
        'Archivada',
        Icons.inventory_2_outlined,
        scheme.surfaceContainerHighest,
      ),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: background,
    );
  }
}
