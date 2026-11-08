import 'package:flutter/material.dart';

import '../../domain/member/club_member.dart';
import 'member_status_chip.dart';
import 'members_view_model.dart';

/// Member record for the club admin, with leave / come back actions.
class MemberDetailSheet extends StatelessWidget {
  const MemberDetailSheet({
    super.key,
    required this.member,
    required this.viewModel,
  });

  final ClubMember member;
  final MembersViewModel viewModel;

  Future<void> _deactivate(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Dar de baja a ${member.displayName}?'),
        content: const Text(
          'Dejará de ver el club en la app. Conservará su número de socio y '
          'su historial, y podrás reactivarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-deactivate-member'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await _run(navigator, messenger, () => viewModel.deactivate(member));
  }

  Future<void> _run(
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
    Future<String> Function() action,
  ) async {
    try {
      final message = await action();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthDate = member.birthDate;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FutureBuilder<String?>(
                  future: viewModel.photoUrl(member),
                  builder: (context, snapshot) => CircleAvatar(
                    radius: 32,
                    backgroundImage: snapshot.data == null
                        ? null
                        : NetworkImage(snapshot.data!),
                    onBackgroundImageError: snapshot.data == null
                        ? null
                        : (_, _) {},
                    child: snapshot.data == null
                        ? const Icon(Icons.person, size: 32)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        'Socio nº ${member.memberNumber ?? '–'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                MemberStatusChip(status: member.status),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline),
              title: Text(member.email),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: Text(member.phone ?? 'Sin teléfono'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(
                birthDate == null
                    ? 'Sin fecha de nacimiento'
                    : '${birthDate.day.toString().padLeft(2, '0')}/'
                          '${birthDate.month.toString().padLeft(2, '0')}/'
                          '${birthDate.year}',
              ),
            ),
            const SizedBox(height: 8),
            if (member.isClubAdmin)
              Text(
                'Es el administrador del club',
                style: theme.textTheme.bodySmall,
              )
            else if (member.status == MemberStatus.inactive)
              FilledButton.icon(
                key: const Key('member-reactivate'),
                onPressed: () => _run(
                  Navigator.of(context),
                  ScaffoldMessenger.of(context),
                  () => viewModel.reactivate(member),
                ),
                icon: const Icon(Icons.undo),
                label: const Text('Reactivar'),
              )
            else
              OutlinedButton.icon(
                key: const Key('member-deactivate'),
                onPressed: () => _deactivate(context),
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Dar de baja'),
              ),
          ],
        ),
      ),
    );
  }
}
