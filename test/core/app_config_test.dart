import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/core/config/app_config.dart';

void main() {
  test('validate fails when Supabase defines are missing', () {
    expect(AppConfig.validate, throwsStateError);
  });
}
