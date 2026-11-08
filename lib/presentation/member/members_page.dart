import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/member/club_member.dart';
import '../session/session_view_model.dart';
import 'members_view_model.dart';
import 'new_member_dialog.dart';

/// Members of the club for its administration (§16 Socios).
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final club = context.read<SessionViewModel>().activeClub;
    if (club == null || !club.canAdminister) {
      return const Scaffold(
        body: Center(
          child: Text('Solo el administrador del club puede ver esta pantalla'),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (context) =>
          MembersViewModel(context.read<AppUseCases>(), clubId: club.id)
            ..load(),
      child: const _MembersView(),
    );
  }
}

class _MembersView extends StatelessWidget {
  const _MembersView();

  Future<void> _newMember(BuildContext context) async {
    final viewModel = context.read<MembersViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = await showDialog<String>(
      context: context,
      builder: (_) => NewMemberDialog(
        onSubmit: (name, email) =>
            viewModel.invite(firstName: name, email: email),
      ),
    );
    if (confirmation != null) {
      messenger.showSnackBar(SnackBar(content: Text(confirmation)));
    }
  }

  Future<void> _resend(BuildContext context, ClubMember member) async {
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = context.read<MembersViewModel>();
    try {
      messenger.showSnackBar(
        SnackBar(content: Text(await viewModel.resend(member))),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MembersViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Socios'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-member'),
        onPressed: () => _newMember(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo socio'),
      ),
      body: switch (viewModel) {
        MembersViewModel(isLoading: true, members: []) => const Center(
          child: CircularProgressIndicator(),
        ),
        MembersViewModel(:final loadError?) => Center(child: Text(loadError)),
        MembersViewModel(members: []) => const Center(
          child: Text('Todavía no hay socios. Da de alta al primero.'),
        ),
        _ => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final member in viewModel.members)
              _MemberTile(
                member: member,
                onResend: () => _resend(context, member),
              ),
          ],
        ),
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onResend});

  final ClubMember member;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, background) = switch (member.status) {
      MemberStatus.invited => (
        'Invitado',
        Icons.mail_outline,
        scheme.secondaryContainer,
      ),
      MemberStatus.active => (
        'Activo',
        Icons.check_circle_outline,
        scheme.primaryContainer,
      ),
      MemberStatus.inactive => (
        'Baja',
        Icons.block,
        scheme.surfaceContainerHighest,
      ),
    };
    return ListTile(
      key: Key('member-${member.email}'),
      leading: CircleAvatar(
        child: Text(member.memberNumber?.toString() ?? '–'),
      ),
      title: Text(member.displayName),
      subtitle: Text(
        [member.email, if (member.isClubAdmin) 'Administrador'].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(icon, size: 16),
            label: Text(label),
            backgroundColor: background,
          ),
          if (member.status == MemberStatus.invited)
            IconButton(
              key: Key('resend-${member.email}'),
              tooltip: 'Reenviar invitación',
              icon: const Icon(Icons.forward_to_inbox),
              onPressed: onResend,
            ),
        ],
      ),
    );
  }
}
