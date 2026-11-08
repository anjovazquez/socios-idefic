import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/card/card_validation.dart';
import '../club/club_avatar.dart';
import '../theme/club_theme.dart';

/// Public screen opened by scanning a card QR (RF-020): club, photo, name,
/// member number, season and whether the card is valid. Nothing else.
class CardValidationPage extends StatefulWidget {
  const CardValidationPage({super.key, required this.token});

  final String token;

  @override
  State<CardValidationPage> createState() => _CardValidationPageState();
}

class _CardValidationPageState extends State<CardValidationPage> {
  late final Future<CardValidation> _result = context
      .read<AppUseCases>()
      .validateCard(widget.token);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<CardValidation>(
          future: _result,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'No hemos podido comprobar el carnet. Inténtalo de nuevo',
                ),
              );
            }
            final result = snapshot.data;
            if (result == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final (label, icon, background) = switch (result.state) {
              ValidationState.active => (
                'SOCIO ACTIVO',
                Icons.verified,
                BrandTokens.valid,
              ),
              ValidationState.notCurrent => (
                'NO VÁLIDO PARA LA TEMPORADA ACTUAL',
                Icons.block,
                BrandTokens.invalid,
              ),
              ValidationState.notFound => (
                'CARNET NO ENCONTRADO',
                Icons.help_outline,
                BrandTokens.invalid,
              ),
            };
            final foreground = readableOn(background);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.clubName case final club?)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClubAvatar(
                              name: club,
                              logoUrl: result.clubLogoUrl,
                              primaryColor: result.primaryColor,
                              radius: 20,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                club,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                      if (result.state != ValidationState.notFound) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: CircleAvatar(
                            radius: 64,
                            backgroundImage: result.photoUrl == null
                                ? null
                                : NetworkImage(result.photoUrl!),
                            onBackgroundImageError: result.photoUrl == null
                                ? null
                                : (_, _) {},
                            child: result.photoUrl == null
                                ? const Icon(Icons.person, size: 64)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          result.fullName,
                          key: const Key('validation-name'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          'Socio nº ${result.memberNumber ?? '–'} · '
                          'Temporada ${result.seasonName ?? '–'}',
                          key: const Key('validation-details'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        key: const Key('validation-state'),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(icon, size: 48, color: foreground),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
