import 'package:intl/intl.dart';

// Module-static: NumberFormat parses its pattern on construction.
final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Format a wire CTC string (Pydantic Decimal → JSON string) as Indian-grouped
/// rupees. Returns '—' for null/unparseable.
String formatCtc(String? raw) {
  if (raw == null) return '—';
  final v = double.tryParse(raw);
  if (v == null) return '—';
  return _inr.format(v);
}
