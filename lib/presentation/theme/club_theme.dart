import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens shared by every club (see DESIGN.md §2).
abstract final class BrandTokens {
  /// Used when a club has not chosen a primary color yet.
  static const defaultPrimary = Color(0xFF0B3D91);

  static const light = Color(0xFFFFFFFF);
  static const dark = Color(0xFF111111);

  /// Quick picks offered in the club settings.
  static const presetColors = [
    '#0B3D91',
    '#1565C0',
    '#B3261E',
    '#1B5E20',
    '#E65100',
    '#F2A900',
    '#4A148C',
    '#111111',
  ];

  /// Card validation result (DESIGN.md §2.2), always with icon + text.
  static const valid = Color(0xFF1B5E20);
  static const invalid = Color(0xFFB3261E);

  /// WCAG AA for normal text.
  static const minContrast = 4.5;
}

/// Parses a `#RRGGBB` club color.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex.trim())) {
    return null;
  }
  return Color(int.parse('FF${hex.trim().substring(1)}', radix: 16));
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Text/icon color with the best contrast on [background].
Color readableOn(Color background) =>
    contrastRatio(BrandTokens.light, background) >=
        contrastRatio(BrandTokens.dark, background)
    ? BrandTokens.light
    : BrandTokens.dark;

/// Theme of the active club (§20): its exact primary color in the header,
/// navigation and main actions, with readable foregrounds.
ThemeData buildClubTheme({String? primaryHex, String? secondaryHex}) {
  final primary = parseHexColor(primaryHex) ?? BrandTokens.defaultPrimary;
  final secondary = parseHexColor(secondaryHex);
  var scheme = ColorScheme.fromSeed(
    seedColor: primary,
  ).copyWith(primary: primary, onPrimary: readableOn(primary));
  if (secondary != null) {
    scheme = scheme.copyWith(
      secondary: secondary,
      onSecondary: readableOn(secondary),
    );
  }
  return ThemeData(
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
  );
}
