import 'package:go_router/go_router.dart';

import 'placeholder_page.dart';

GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const PlaceholderPage()),
  ],
);
