/// `5000` → `50,00 €` (Spanish format, thousands with a dot).
String formatCents(int cents) {
  final negative = cents < 0;
  final value = cents.abs();
  final euros = (value ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < euros.length; i++) {
    if (i > 0 && (euros.length - i) % 3 == 0) grouped.write('.');
    grouped.write(euros[i]);
  }
  final decimals = (value % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$grouped,$decimals €';
}

/// `5000` → `50` / `5050` → `50,50`, for prefilling amount fields.
String centsToInput(int cents) => cents % 100 == 0
    ? '${cents ~/ 100}'
    : '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

/// `dd/MM/yyyy`.
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// `1 de septiembre de 2027`.
String formatLongDate(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]} de ${date.year}';
