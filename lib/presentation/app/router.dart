import 'package:go_router/go_router.dart';

import '../auth/login_page.dart';
import '../club/club_home_page.dart';
import '../club/club_selector_page.dart';
import '../session/session_status_pages.dart';
import '../session/session_view_model.dart';

abstract final class AppRoutes {
  static const loading = '/';
  static const login = '/login';
  static const clubs = '/clubs';
  static const club = '/club';
  static const noClubs = '/no-clubs';
  static const error = '/error';
}

/// Every session status owns exactly one route; protected routes are never
/// reachable without a session.
String routeFor(SessionStatus status) => switch (status) {
  SessionStatus.loading => AppRoutes.loading,
  SessionStatus.signedOut => AppRoutes.login,
  SessionStatus.noClubs => AppRoutes.noClubs,
  SessionStatus.choosingClub => AppRoutes.clubs,
  SessionStatus.inClub => AppRoutes.club,
  SessionStatus.error => AppRoutes.error,
};

GoRouter createRouter(SessionViewModel session, {String? initialLocation}) =>
    GoRouter(
      initialLocation: initialLocation ?? AppRoutes.loading,
      refreshListenable: session,
      redirect: (context, state) {
        final target = routeFor(session.status);
        return state.matchedLocation == target ? null : target;
      },
      routes: [
        GoRoute(
          path: AppRoutes.loading,
          builder: (context, state) => const LoadingPage(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.clubs,
          builder: (context, state) => const ClubSelectorPage(),
        ),
        GoRoute(
          path: AppRoutes.club,
          builder: (context, state) => const ClubHomePage(),
        ),
        GoRoute(
          path: AppRoutes.noClubs,
          builder: (context, state) => const NoClubsPage(),
        ),
        GoRoute(
          path: AppRoutes.error,
          builder: (context, state) => const SessionErrorPage(),
        ),
      ],
    );
