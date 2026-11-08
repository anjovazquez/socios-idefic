import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/payment/receipt.dart';
import 'package:socios_idefic/presentation/receipt/pdf_receipt_renderer.dart';

// BDD: tasks/VS-019.md — Descargar recibo (contenido del PDF).
void main() {
  final receipt = Receipt(
    paymentId: '8f2c0c1e-0000-4000-8000-000000000002',
    number: 2,
    clubName: 'IDEFIC',
    clubCode: 'IDEFIC',
    clubPrimaryColor: '#0B3D91',
    memberName: 'Ana Pérez',
    memberNumber: 2,
    seasonName: '2026/2027',
    concept: 'Cuota de socio 2026/2027',
    amountCents: 5000,
    method: PaymentMethod.transfer,
    paidAt: DateTime(2026, 9, 10),
  );

  test('the code is correlative and padded per club', () {
    expect(receipt.code, 'IDEFIC-0002');
    expect(receipt.fileName, 'recibo-IDEFIC-0002.pdf');
  });

  test('the receipt lists member, number, season, concept, date, method '
      'and payment id', () {
    expect(receiptLines(receipt), [
      ('Socio', 'Ana Pérez'),
      ('Número de socio', '2'),
      ('Temporada', '2026/2027'),
      ('Concepto', 'Cuota de socio 2026/2027'),
      ('Fecha de pago', '10/09/2026'),
      ('Método', 'Transferencia'),
      ('Identificador del pago', '8f2c0c1e-0000-4000-8000-000000000002'),
    ]);
  });

  testWidgets('the PDF builds with the bundled Unicode fonts', (tester) async {
    final bytes = await tester.runAsync(
      () async => buildReceiptPdf(receipt, theme: await loadReceiptTheme()),
    );
    expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
