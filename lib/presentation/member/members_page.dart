import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/member/club_member.dart';
import '../session/session_view_model.dart';
import '../format/money.dart';
import '../season/season_membership_chip.dart';
import 'member_detail_sheet.dart';
import 'member_number_dialog.dart';
import 'member_status_chip.dart';
import 'members_view_model.dart';
import 'new_member_dialog.dart';

/// Members of the club for its administration (§16 Socios).
class MembersPage extends StatelessWidget {
  const MembersPage({super.key, this.openNew = false});

  /// Opens «Nuevo socio» on arrival (dashboard shortcut).
  final bool openNew;

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
      child: _MembersView(openNew: openNew),
    );
  }
}

class _MembersView extends StatefulWidget {
  const _MembersView({this.openNew = false});

  final bool openNew;

  @override
  State<_MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends State<_MembersView> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.openNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _newMember(context);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => context.read<MembersViewModel>().search(value),
    );
  }

  void _showDetail(BuildContext context, ClubMember member) {
    final viewModel = context.read<MembersViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MemberDetailSheet(member: member, viewModel: viewModel),
    );
  }

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
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(confirmation)));
    }
  }

  Future<void> _editNumber(BuildContext context, ClubMember member) async {
    final viewModel = context.read<MembersViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = await showDialog<String>(
      context: context,
      builder: (_) => MemberNumberDialog(
        member: member,
        onSubmit: (number) => viewModel.changeNumber(member, number),
      ),
    );
    if (confirmation != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(confirmation)));
    }
  }

  Future<void> _resend(BuildContext context, ClubMember member) async {
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = context.read<MembersViewModel>();
    try {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(await viewModel.resend(member))));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('members-search'),
              onChanged: _onSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre, email o número',
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final (status, label) in [
                  (null, 'Todos'),
                  (MemberStatus.active, 'Activos'),
                  (MemberStatus.invited, 'Invitados'),
                  (MemberStatus.inactive, 'Baja'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('members-filter-${status?.name ?? 'all'}'),
                      label: Text(label),
                      selected: viewModel.status == status,
                      onSelected: (_) => viewModel.filter(status),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                viewModel.total == 1 ? '1 socio' : '${viewModel.total} socios',
                key: const Key('members-total'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          Expanded(
            child: switch (viewModel) {
              MembersViewModel(isLoading: true, members: []) => const Center(
                child: CircularProgressIndicator(),
              ),
              MembersViewModel(:final loadError?) => Center(
                child: Text(loadError),
              ),
              MembersViewModel(members: [], query: '', status: null) =>
                const Center(
                  child: Text('Todavía no hay socios. Da de alta al primero.'),
                ),
              MembersViewModel(members: []) => const Center(
                child: Text('Ningún socio coincide con la búsqueda'),
              ),
              _ => ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final member in viewModel.members)
                    _MemberTile(
                      member: member,
                      onResend: () => _resend(context, member),
                      onEditNumber: () => _editNumber(context, member),
                      onOpen: () => _showDetail(context, member),
                    ),
                  if (viewModel.hasMore)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton(
                        key: const Key('members-more'),
                        onPressed: viewModel.isLoading
                            ? null
                            : viewModel.loadMore,
                        child: const Text('Ver más'),
                      ),
                    ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onResend,
    required this.onEditNumber,
    required this.onOpen,
  });

  final ClubMember member;
  final VoidCallback onResend;
  final VoidCallback onEditNumber;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('member-${member.email}'),
      onTap: onOpen,
      leading: Tooltip(
        message: 'Cambiar número de socio',
        child: InkWell(
          key: Key('member-number-${member.email}'),
          customBorder: const CircleBorder(),
          onTap: onEditNumber,
          child: CircleAvatar(
            child: Text(member.memberNumber?.toString() ?? '–'),
          ),
        ),
      ),
      title: Text(member.displayName),
      subtitle: Text(
        [
          member.email,
          if (member.isClubAdmin) 'Administrador',
          if (member.seasonStatus case final status?)
            '${formatCents(member.seasonFeeCents ?? 0)} · '
                '${SeasonMembershipChip.label(status)}',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MemberStatusChip(status: member.status),
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
