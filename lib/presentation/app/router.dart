import 'package:go_router/go_router.dart';

import '../auth/login_page.dart';
import '../club/club_home_page.dart';
import '../club/club_settings_page.dart';
import '../club/club_selector_page.dart';
import '../platform/audit_log_page.dart';
import '../platform/platform_clubs_page.dart';
import '../session/session_status_pages.dart';
import '../session/session_view_model.dart';

abstract final class AppRoutes {
  static const loading = '/';
  static const login = '/login';
  static const clubs = '/clubs';
  static const club = '/club';
  static const noClubs = '/no-clubs';
  static const platform = '/platform';
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
  SessionStatus.platform => AppRoutes.platform,
  SessionStatus.error => AppRoutes.error,
};

/// Keeps the user inside the area of their session status; sub-routes of
/// that area (e.g. `/club/settings`) are allowed.
String? redirectFor(SessionStatus status, String location) {
  final target = routeFor(status);
  if (location == target) return null;
  if (target != AppRoutes.loading && location.startsWith('$target/')) {
    return null;
  }
  return target;
}

GoRouter createRouter(SessionViewModel session, {String? initialLocation}) =>
    GoRouter(
      initialLocation: initialLocation ?? AppRoutes.loading,
      refreshListenable: session,
      redirect: (context, state) =>
          redirectFor(session.status, state.matchedLocation),
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
          routes: [
            GoRoute(
              path: 'settings',
              builder: (context, state) => const ClubSettingsPage(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.noClubs,
          builder: (context, state) => const NoClubsPage(),
        ),
        GoRoute(
          path: AppRoutes.platform,
          builder: (context, state) => const PlatformClubsPage(),
          routes: [
            GoRoute(
              path: 'audit',
              builder: (context, state) => const AuditLogPage(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.error,
          builder: (context, state) => const SessionErrorPage(),
        ),
      ],
    );
