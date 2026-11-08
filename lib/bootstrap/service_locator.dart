import 'package:get_it/get_it.dart';

/// Composition root. Only this layer knows about GetIt.
final GetIt serviceLocator = GetIt.instance;

/// Registers adapters and use cases. Slices add their own registrations here
/// when they need them; nothing is registered ahead of time.
void configureDependencies() {}
