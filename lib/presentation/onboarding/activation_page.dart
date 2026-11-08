import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/onboarding/onboarding.dart';
import 'onboarding_messages.dart';

/// Opens an invitation link: verifies the one-time token and signs in. The
/// session then moves to the first-access screen.
class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key, this.tokenHash, this.type});

  final String? tokenHash;
  final String? type;

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      await context.read<AppUseCases>().verifyInvitationLink(
        tokenHash: widget.tokenHash,
        type: widget.type,
      );
    } on OnboardingFailure catch (failure) {
      if (mounted) setState(() => _error = onboardingMessage(failure));
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = onboardingMessage(const OnboardingUnavailableFailure()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: error == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Comprobando tu invitación…'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No hemos podido activar tu cuenta',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error,
                        key: const Key('activation-error'),
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Ir a iniciar sesión'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
