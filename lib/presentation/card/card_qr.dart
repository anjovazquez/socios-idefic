import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/app_config.dart';
import '../../domain/card/card_validation.dart';

/// Base URL of the public validation page.
String publicAppUrl() => AppConfig.publicAppUrl.isNotEmpty
    ? AppConfig.publicAppUrl
    : kIsWeb
    ? Uri.base.origin
    : '';

/// QR of an active card: opens `/#/v/<token>` (RF-020).
class CardQr extends StatelessWidget {
  const CardQr({super.key, required this.token, this.baseUrl});

  final String token;

  /// Overrides [publicAppUrl] (tests).
  final String? baseUrl;

  @override
  Widget build(BuildContext context) {
    final data = cardValidationUrl(baseUrl ?? publicAppUrl(), token);
    return Semantics(
      label: 'Código QR del carnet',
      child: QrImageView(
        key: const Key('card-qr'),
        data: data,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}
