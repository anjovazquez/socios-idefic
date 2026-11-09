import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/card/membership_card.dart';
import 'package:socios_idefic/presentation/card/membership_card_view.dart';
import 'package:socios_idefic/presentation/club/club_shell.dart';
import 'package:socios_idefic/presentation/theme/club_theme.dart';

// Golden tests of key screens (VS-032). Regenerate after an intended visual
// change with: flutter test --update-goldens test/golden
void main() {
  Widget themed(Widget child, {String primary = '#0B3D91'}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildClubTheme(primaryHex: primary, secondaryHex: '#F2A900'),
    home: child,
  );

  testWidgets('membership card (active)', (tester) async {
    tester.view.physicalSize = const Size(520, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(8),
            child: MembershipCardView(
              card: MembershipCard(
                clubName: 'IDEFIC',
                state: CardState.active,
                primaryColor: '#0B3D91',
                secondaryColor: '#F2A900',
                firstName: 'Ana',
                lastName: 'Pérez',
                memberNumber: 2,
                seasonName: '2026/2027',
              ),
              qr: ColoredBox(color: Colors.black12),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MembershipCardView),
      matchesGoldenFile('goldens/membership_card_active.png'),
    );
  });

  for (final (name, color) in [('idefic', '#0B3D91'), ('demo', '#B3261E')]) {
    testWidgets('member navigation with the club colors ($name)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          const ClubShell(location: '/club/card', child: SizedBox.expand()),
          primary: color,
        ),
      );
      await expectLater(
        find.byKey(const Key('club-navigation')),
        matchesGoldenFile('goldens/club_navigation_$name.png'),
      );
    });
  }
}
