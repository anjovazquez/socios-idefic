import 'package:flutter/material.dart';

/// Temporary home until VS-001 adds login and the club selector.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Socios IDEFIC',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
