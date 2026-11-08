import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/presentation/theme/club_theme.dart';

void main() {
  test('uses the exact club color as primary', () {
    final theme = buildClubTheme(
      primaryHex: '#B3261E',
      secondaryHex: '#F2A900',
    );

    expect(theme.colorScheme.primary, const Color(0xFFB3261E));
    expect(theme.colorScheme.secondary, const Color(0xFFF2A900));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFFB3261E));
  });

  test('falls back to the default color', () {
    expect(
      buildClubTheme(primaryHex: 'nope').colorScheme.primary,
      BrandTokens.defaultPrimary,
    );
  });

  for (final hex in ['#FFF59D', '#FFFFFF', '#F2A900', '#0B3D91', '#111111']) {
    test('text on $hex reaches WCAG AA', () {
      final background = parseHexColor(hex)!;
      final theme = buildClubTheme(primaryHex: hex);

      expect(
        contrastRatio(theme.colorScheme.onPrimary, background),
        greaterThanOrEqualTo(BrandTokens.minContrast),
      );
    });
  }

  test('very light colors get dark text', () {
    expect(readableOn(parseHexColor('#FFF59D')!), BrandTokens.dark);
    expect(readableOn(parseHexColor('#0B3D91')!), BrandTokens.light);
  });
}
