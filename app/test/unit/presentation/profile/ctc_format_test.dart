import 'package:flutter_test/flutter_test.dart';
import 'package:kpa_app/presentation/profile/ctc_format.dart';

void main() {
  test('formats Indian-grouped rupees', () {
    expect(formatCtc('1200000.00'), '₹12,00,000');
  });
  test('null and unparseable → dash', () {
    expect(formatCtc(null), '—');
    expect(formatCtc('abc'), '—');
  });
}
