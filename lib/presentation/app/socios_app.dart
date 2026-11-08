import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

class SociosApp extends StatefulWidget {
  const SociosApp({super.key, this.router});

  /// Injectable for tests.
  final GoRouter? router;

  @override
  State<SociosApp> createState() => _SociosAppState();
}

class _SociosAppState extends State<SociosApp> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Socios IDEFIC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B3D91)),
      ),
      routerConfig: _router,
    );
  }
}
