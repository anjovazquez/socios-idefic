import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a management section from the admin «Gestión» menu (VS-032).
Future<void> openAdminSection(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const Key('open-admin-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
}
