import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/app_use_cases.dart';
import '../application/auth/sign_in_with_password.dart';
import '../application/auth/sign_out.dart';
import '../application/auth/watch_session.dart';
import '../application/club/resolve_club_entry.dart';
import '../application/club/select_active_club.dart';
import '../domain/auth/auth_repository.dart';
import '../domain/club/active_club_store.dart';
import '../domain/club/club_repository.dart';
import '../infrastructure/auth/supabase_auth_repository.dart';
import '../infrastructure/club/shared_preferences_active_club_store.dart';
import '../infrastructure/club/supabase_club_repository.dart';

/// Composition root. Only this layer knows about GetIt.
final GetIt serviceLocator = GetIt.instance;

void configureDependencies() {
  final client = Supabase.instance.client;

  serviceLocator
    ..registerLazySingleton<AuthRepository>(
      () => SupabaseAuthRepository(client),
    )
    ..registerLazySingleton<ClubRepository>(
      () => SupabaseClubRepository(client),
    )
    ..registerLazySingleton<ActiveClubStore>(
      SharedPreferencesActiveClubStore.new,
    )
    ..registerLazySingleton<AppUseCases>(
      () => AppUseCases(
        watchSession: WatchSession(serviceLocator()),
        signInWithPassword: SignInWithPassword(serviceLocator()),
        signOut: SignOut(serviceLocator(), serviceLocator()),
        resolveClubEntry: ResolveClubEntry(serviceLocator(), serviceLocator()),
        selectActiveClub: SelectActiveClub(serviceLocator()),
      ),
    );
}
