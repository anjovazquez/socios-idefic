import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../auth/login_view_model.dart';
import '../club/image_picking.dart';
import '../session/session_view_model.dart';
import '../theme/club_theme.dart';
import 'router.dart';

class SociosApp extends StatefulWidget {
  const SociosApp({
    super.key,
    required this.useCases,
    this.initialLocation,
    this.pickImage = pickImageFromGallery,
  });

  final AppUseCases useCases;

  /// Device image chooser (injectable for tests).
  final PickImage pickImage;

  /// Deep link used on start (tests and web refreshes).
  final String? initialLocation;

  @override
  State<SociosApp> createState() => _SociosAppState();
}

class _SociosAppState extends State<SociosApp> {
  late final SessionViewModel _session = SessionViewModel(widget.useCases)
    ..start();
  late final GoRouter _router = createRouter(
    _session,
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppUseCases>.value(value: widget.useCases),
        Provider<PickImage>.value(value: widget.pickImage),
        ChangeNotifierProvider.value(value: _session),
        ChangeNotifierProvider(
          create: (_) => LoginViewModel(
            widget.useCases.signInWithPassword,
            widget.useCases.signInWithGoogle,
          ),
        ),
      ],
      child: ListenableBuilder(
        listenable: _session,
        builder: (context, _) => MaterialApp.router(
          title: _session.activeClub?.name ?? 'Socios',
          debugShowCheckedModeBanner: false,
          // The active club tints header, navigation and actions (§20).
          theme: buildClubTheme(
            primaryHex: _session.activeClub?.primaryColor,
            secondaryHex: _session.activeClub?.secondaryColor,
          ),
          routerConfig: _router,
        ),
      ),
    );
  }
}
