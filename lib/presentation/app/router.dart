import 'package:go_router/go_router.dart';

import '../auth/login_page.dart';
import '../card/my_card_page.dart';
import '../club/club_home_page.dart';
import '../club/club_settings_page.dart';
import '../member/members_page.dart';
import '../onboarding/activation_page.dart';
import '../onboarding/onboarding_page.dart';
import '../club/club_selector_page.dart';
import '../platform/audit_log_page.dart';
import '../profile/my_data_page.dart';
import '../season/renewal_page.dart';
import '../season/seasons_page.dart';
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
  static const onboarding = '/primer-acceso';

  /// Target of the invitation emails: `/activar?token_hash=…&type=…`.
  static const activation = '/activar';
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
  SessionStatus.onboarding => AppRoutes.onboarding,
  SessionStatus.error => AppRoutes.error,
};

/// Keeps the user inside the area of their session status; sub-routes of
/// that area (e.g. `/club/settings`) are allowed.
String? redirectFor(SessionStatus status, String location) {
  final target = routeFor(status);
  if (location == target) return null;
  // The invitation link must be opened without a session (it creates one).
  if (location == AppRoutes.activation &&
      (status == SessionStatus.signedOut || status == SessionStatus.loading)) {
    return null;
  }
  if (target != AppRoutes.loading && location.startsWith('$target/')) {
    return null;
  }
  return target;
}

GoRouter createRouter(
  SessionViewModel session, {
  String? initialLocation,
}) => GoRouter(
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
      path: AppRoutes.activation,
      builder: (context, state) => ActivationPage(
        tokenHash: state.uri.queryParameters['token_hash'],
        type: state.uri.queryParameters['type'],
      ),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingPage(),
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
        GoRoute(
          path: 'members',
          builder: (context, state) => const MembersPage(),
        ),
        GoRoute(path: 'card', builder: (context, state) => const MyCardPage()),
        GoRoute(path: 'me', builder: (context, state) => const MyDataPage()),
        GoRoute(
          path: 'seasons',
          builder: (context, state) => const SeasonsPage(),
          routes: [
            GoRoute(
              path: 'renew',
              builder: (context, state) => RenewalPage(
                seasonId: state.uri.queryParameters['season'] ?? '',
                seasonName: state.uri.queryParameters['name'],
              ),
            ),
          ],
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
