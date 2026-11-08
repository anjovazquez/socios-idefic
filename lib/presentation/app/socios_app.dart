import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../auth/login_view_model.dart';
import '../session/session_view_model.dart';
import 'router.dart';

class SociosApp extends StatefulWidget {
  const SociosApp({super.key, required this.useCases, this.initialLocation});

  final AppUseCases useCases;

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
        ChangeNotifierProvider.value(value: _session),
        ChangeNotifierProvider(
          create: (_) => LoginViewModel(
            widget.useCases.signInWithPassword,
            widget.useCases.signInWithGoogle,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'Socios',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3D91)),
        ),
        routerConfig: _router,
      ),
    );
  }
}
