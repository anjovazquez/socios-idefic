import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import 'audit_labels.dart';
import 'audit_log_view_model.dart';

/// Who did what, and whether it was done as platform admin (§17).
class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          AuditLogViewModel(context.read<AppUseCases>())..load(),
      child: const _AuditLogView(),
    );
  }
}

class _AuditLogView extends StatelessWidget {
  const _AuditLogView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuditLogViewModel>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría'),
        leading: BackButton(onPressed: () => context.go('/platform')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String?>(
              key: const Key('audit-club-filter'),
              initialValue: viewModel.clubId,
              decoration: const InputDecoration(labelText: 'Club'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos los clubes'),
                ),
                for (final club in viewModel.clubs)
                  DropdownMenuItem(value: club.id, child: Text(club.name)),
              ],
              onChanged: viewModel.filterByClub,
            ),
          ),
          if (viewModel.error case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: viewModel.entries.isEmpty && !viewModel.isLoading
                ? const Center(
                    child: Text('Todavía no hay acciones registradas'),
                  )
                : ListView(
                    children: [
                      for (final entry in viewModel.entries)
                        ListTile(
                          key: Key('audit-${entry.id}'),
                          title: Text(
                            [
                              auditActionLabel(entry.action),
                              ?auditDetail(entry),
                            ].join(' · '),
                          ),
                          subtitle: Text(
                            '${entry.clubName ?? 'Plataforma'} · '
                            '${entry.actorEmail ?? 'Desconocido'} · '
                            '${formatAuditDate(entry.createdAt)}',
                          ),
                          trailing: entry.asPlatformAdmin
                              ? Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Como plataforma'),
                                  backgroundColor:
                                      theme.colorScheme.tertiaryContainer,
                                )
                              : null,
                        ),
                      if (viewModel.hasMore)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton(
                            onPressed: viewModel.isLoading
                                ? null
                                : viewModel.loadMore,
                            child: const Text('Ver más'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
