import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/app_use_cases.dart';
import '../core/config/app_config.dart';
import '../presentation/app/socios_app.dart';
import 'service_locator.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.validate();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  configureDependencies();

  runApp(SociosApp(useCases: serviceLocator<AppUseCases>()));
}
