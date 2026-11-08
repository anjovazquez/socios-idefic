import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/payment/my_subscription.dart';

/// «Mi suscripción»: current season and payment history (RF-011, RF-016).
class MySubscriptionViewModel extends ChangeNotifier {
  MySubscriptionViewModel(this._useCases, {required this.clubId});

  final AppUseCases _useCases;
  final String clubId;

  MySubscription? _subscription;
  MySubscription? get subscription => _subscription;

  List<MyPayment> _payments = const [];
  List<MyPayment> get payments => _payments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _useCases.getMySubscription(clubId),
        _useCases.getMyPayments(clubId),
      ]);
      _subscription = results[0] as MySubscription;
      _payments = results[1] as List<MyPayment>;
    } catch (_) {
      _loadError =
          'No hemos podido cargar tu suscripción. Inténtalo de nuevo en un '
          'momento';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
