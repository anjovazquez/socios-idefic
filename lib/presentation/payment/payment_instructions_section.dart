import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';

/// How members pay the fee outside the app (manual provider, D-011).
class PaymentInstructionsViewModel extends ChangeNotifier {
  PaymentInstructionsViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  String? _instructions;
  String? get instructions => _instructions;

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _saving = false;
  bool get saving => _saving;

  Future<void> load() async {
    try {
      _instructions = await _useCases.getPaymentInstructions(clubId);
    } catch (_) {
      _instructions = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<bool> save(String text) async {
    _saving = true;
    notifyListeners();
    try {
      await _useCases.setPaymentInstructions(clubId, text);
      _instructions = text.trim().isEmpty ? null : text.trim();
      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}

class PaymentInstructionsSection extends StatelessWidget {
  const PaymentInstructionsSection({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => PaymentInstructionsViewModel(
      context.read<AppUseCases>(),
      clubId: clubId,
    )..load(),
    child: const _Section(),
  );
}

class _Section extends StatefulWidget {
  const _Section();

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  final _text = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PaymentInstructionsViewModel>();
    final theme = Theme.of(context);
    if (viewModel.loaded && !_filled) {
      _text.text = viewModel.instructions ?? '';
      _filled = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pago de cuotas', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('payment-instructions'),
          controller: _text,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Cómo pagar la cuota',
            hintText: 'IBAN para transferencias, número de Bizum…',
            helperText: 'Lo verán los socios con la cuota pendiente',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('payment-instructions-save'),
            onPressed: viewModel.saving
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final saved = await viewModel.save(_text.text);
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            saved
                                ? 'Instrucciones de pago guardadas'
                                : 'No hemos podido guardarlas. Inténtalo de '
                                      'nuevo',
                          ),
                        ),
                      );
                  },
            child: const Text('Guardar instrucciones'),
          ),
        ),
      ],
    );
  }
}
