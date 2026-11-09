import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Member sections of the club area (§14): bottom bar on phones, rail on
/// wide screens. Colors come from the club theme (§20).
class ClubShell extends StatelessWidget {
  const ClubShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  /// Wide layouts (admin on the web) use a side rail.
  static const railBreakpoint = 1024.0;

  static const sections = [
    _Section('/club', 'Inicio', Icons.home_outlined, Icons.home, 'open-home'),
    _Section(
      '/club/card',
      'Mi carnet',
      Icons.badge_outlined,
      Icons.badge,
      'open-card',
    ),
    _Section(
      '/club/benefits',
      'Mis ventajas',
      Icons.local_offer_outlined,
      Icons.local_offer,
      'open-my-perks',
    ),
    _Section(
      '/club/subscription',
      'Mi suscripción',
      Icons.receipt_long_outlined,
      Icons.receipt_long,
      'open-subscription',
    ),
    _Section(
      '/club/me',
      'Mis datos',
      Icons.person_outline,
      Icons.person,
      'open-my-data',
    ),
  ];

  /// Section of [location]; anything else in the club area is «Inicio»
  /// (news, management pages).
  static int indexOf(String location) {
    for (var i = sections.length - 1; i > 0; i--) {
      final path = sections[i].path;
      if (location == path || location.startsWith('$path/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Pages show their SnackBars in their own Scaffold (above their FAB),
    // not over the navigation bar of the shell.
    final page = ScaffoldMessenger(child: child);
    final selected = indexOf(location);
    void open(int index) => context.go(sections[index].path);
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              key: const Key('club-rail'),
              selectedIndex: selected,
              onDestinationSelected: open,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final s in sections)
                  NavigationRailDestination(
                    icon: Icon(s.icon),
                    selectedIcon: Icon(s.selectedIcon),
                    label: Text(s.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }
    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        key: const Key('club-navigation'),
        selectedIndex: selected,
        onDestinationSelected: open,
        destinations: [
          for (final s in sections)
            NavigationDestination(
              key: Key(s.key),
              icon: Icon(s.icon),
              selectedIcon: Icon(s.selectedIcon),
              label: s.label,
            ),
        ],
      ),
    );
  }
}

class _Section {
  const _Section(this.path, this.label, this.icon, this.selectedIcon, this.key);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String key;
}
