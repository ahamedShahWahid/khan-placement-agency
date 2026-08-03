import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/presentation/profile/ctc_format.dart';

void main() {
  test('formats Indian-grouped rupees', () {
    expect(formatCtc('1200000.00'), '₹12,00,000');
  });
  test('null and unparseable → dash', () {
    expect(formatCtc(null), '—');
    expect(formatCtc('abc'), '—');
  });

  test('formatYearsNumber drops trailing .0 but keeps real decimals', () {
    expect(formatYearsNumber('5.0'), '5');
    expect(formatYearsNumber('4.5'), '4.5');
  });
  test('formatYearsNumber null/unparseable → null', () {
    expect(formatYearsNumber(null), isNull);
    expect(formatYearsNumber('abc'), isNull);
  });
}
