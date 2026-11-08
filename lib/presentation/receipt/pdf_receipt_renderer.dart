import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/payment/receipt.dart';
import '../format/money.dart';
import '../payment/payment_labels.dart';
import '../theme/club_theme.dart';

/// PDF receipt built on the device (D-015) and handed to the platform: a
/// download on the web, the share sheet on mobile.
class PdfReceiptRenderer implements ReceiptRenderer {
  const PdfReceiptRenderer();

  @override
  Future<void> deliver(Receipt receipt) async {
    Uint8List? logo;
    if (receipt.clubLogoUrl != null) {
      try {
        final image = await networkImage(receipt.clubLogoUrl!);
        logo = image is pw.MemoryImage ? image.bytes : null;
      } catch (_) {
        // The receipt is still valid without the logo.
      }
    }
    final bytes = await buildReceiptPdf(
      receipt,
      theme: await loadReceiptTheme(),
      logo: logo,
    );
    await Printing.sharePdf(bytes: bytes, filename: receipt.fileName);
  }
}

/// Roboto (bundled) so accents and «€» render in every viewer.
Future<pw.ThemeData> loadReceiptTheme() async => pw.ThemeData.withFont(
  base: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf')),
  bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
);

/// Label/value lines of the receipt, in order (RF-017 minimum content).
List<(String, String)> receiptLines(Receipt receipt) => [
  ('Socio', receipt.memberName),
  if (receipt.memberNumber != null)
    ('Número de socio', '${receipt.memberNumber}'),
  ('Temporada', receipt.seasonName),
  ('Concepto', receipt.concept),
  ('Fecha de pago', formatDate(receipt.paidAt.toLocal())),
  if (receipt.method != null) ('Método', paymentMethodLabel(receipt.method!)),
  ('Identificador del pago', receipt.paymentId),
];

/// The receipt document.
Future<Uint8List> buildReceiptPdf(
  Receipt receipt, {
  required pw.ThemeData theme,
  Uint8List? logo,
}) {
  final brand =
      parseHexColor(receipt.clubPrimaryColor) ?? BrandTokens.defaultPrimary;
  final primary = PdfColor.fromInt(brand.toARGB32());
  final onPrimary = PdfColor.fromInt(readableOn(brand).toARGB32());
  final document = pw.Document(
    theme: theme,
    title: 'Recibo ${receipt.code}',
    author: receipt.clubName,
  );

  pw.Widget row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(child: pw.Text(value)),
      ],
    ),
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            color: primary,
            child: pw.Row(
              children: [
                if (logo != null)
                  pw.Container(
                    width: 56,
                    height: 56,
                    margin: const pw.EdgeInsets.only(right: 16),
                    padding: const pw.EdgeInsets.all(4),
                    color: PdfColors.white,
                    child: pw.Image(
                      pw.MemoryImage(logo),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        receipt.clubName,
                        style: pw.TextStyle(
                          color: onPrimary,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Recibo de pago',
                        style: pw.TextStyle(color: onPrimary),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  'Nº ${receipt.code}',
                  style: pw.TextStyle(
                    color: onPrimary,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          for (final (label, value) in receiptLines(receipt)) row(label, value),
          pw.Divider(color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Importe',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                formatCents(receipt.amountCents),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Text(
            'Recibo emitido por ${receipt.clubName} con Socios. Conserva este '
            'documento como justificante de pago.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );
  return document.save();
}
