import 'package:flutter/material.dart';

import '../../domain/season/season.dart';
import '../common/submit_dialog.dart';
import '../format/money.dart';

/// New season: name suggested after the newest one; dates by default
/// 1 September – 31 August.
class NewSeasonDialog extends StatefulWidget {
  const NewSeasonDialog({
    super.key,
    required this.suggestedName,
    required this.onSubmit,
  });

  final String suggestedName;
  final Future<String> Function(String name) onSubmit;

  @override
  State<NewSeasonDialog> createState() => _NewSeasonDialogState();
}

class _NewSeasonDialogState extends State<NewSeasonDialog> {
  late final _name = TextEditingController(text: widget.suggestedName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SubmitDialog(
    title: 'Nueva temporada',
    action: 'Crear',
    saveKey: const Key('new-season-save'),
    onSubmit: () => widget.onSubmit(_name.text),
    builder: (context, _) => [
      TextField(
        key: const Key('new-season-name'),
        controller: _name,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          helperText: 'Del 1 de septiembre al 31 de agosto',
        ),
      ),
    ],
  );
}

/// Activates a season with its ordinary fee (RF-008).
class ActivateSeasonDialog extends StatefulWidget {
  const ActivateSeasonDialog({
    super.key,
    required this.season,
    required this.currentActive,
    required this.onSubmit,
  });

  final Season season;
  final Season? currentActive;
  final Future<String> Function(String fee) onSubmit;

  @override
  State<ActivateSeasonDialog> createState() => _ActivateSeasonDialogState();
}

class _ActivateSeasonDialogState extends State<ActivateSeasonDialog> {
  late final _fee = TextEditingController(
    text: switch (widget.season.defaultFeeCents ??
        widget.currentActive?.defaultFeeCents) {
      final int cents => centsToInput(cents),
      _ => '',
    },
  );

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.currentActive;
    final isActive = widget.season.status == SeasonStatus.active;
    return SubmitDialog(
      title: isActive
          ? 'Cuota de ${widget.season.name}'
          : 'Activar ${widget.season.name}',
      action: isActive ? 'Guardar' : 'Activar',
      saveKey: const Key('activate-season-save'),
      onSubmit: () => widget.onSubmit(_fee.text),
      builder: (context, _) => [
        TextField(
          key: const Key('activate-season-fee'),
          controller: _fee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cuota ordinaria',
            suffixText: '€',
            helperText: 'Es la cuota propuesta para todos los socios',
          ),
        ),
        if (!isActive && previous != null && previous.id != widget.season.id)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${previous.name} dejará de ser la temporada activa y pasará a '
              'temporadas anteriores.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// Automatic renewal charge date and notice days of a season (VS-023).
class RenewalChargeDialog extends StatefulWidget {
  const RenewalChargeDialog({
    super.key,
    required this.season,
    required this.onSubmit,
  });

  final Season season;
  final Future<String> Function(DateTime chargeOn, String noticeDays) onSubmit;

  @override
  State<RenewalChargeDialog> createState() => _RenewalChargeDialogState();
}

class _RenewalChargeDialogState extends State<RenewalChargeDialog> {
  late DateTime _chargeOn = widget.season.chargeOn;
  late final _days = TextEditingController(
    text: '${widget.season.renewalNoticeDays}',
  );

  @override
  void initState() {
    super.initState();
    _days.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chargeOn,
      firstDate: DateTime(widget.season.startsOn.year - 1),
      lastDate: widget.season.endsOn,
    );
    if (picked != null) setState(() => _chargeOn = picked);
  }

  @override
  Widget build(BuildContext context) {
    final days = int.tryParse(_days.text.trim());
    final noticeOn = days == null
        ? null
        : _chargeOn.subtract(Duration(days: days));
    return SubmitDialog(
      title: 'Cobro automático de ${widget.season.name}',
      action: 'Guardar',
      saveKey: const Key('renewal-charge-save'),
      onSubmit: () => widget.onSubmit(_chargeOn, _days.text),
      builder: (context, _) => [
        Text(
          'Solo para socios con renovación automática y método guardado.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ListTile(
          key: const Key('renewal-charge-date'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Fecha del cobro'),
          subtitle: Text(formatDate(_chargeOn)),
          trailing: const Text('Cambiar'),
          onTap: _pickDate,
        ),
        TextField(
          key: const Key('renewal-notice-days'),
          controller: _days,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Días de aviso antes del cobro',
            suffixText: 'días',
            helperText: noticeOn == null
                ? 'De 1 a 60 días'
                : 'El aviso se enviará el ${formatDate(noticeOn)}',
          ),
        ),
      ],
    );
  }
}
