import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

void main() {
  testWidgets('app starts on the placeholder home', (tester) async {
    await tester.pumpWidget(const SociosApp());
    await tester.pumpAndSettle();

    expect(find.text('Socios IDEFIC'), findsOneWidget);
  });
}
