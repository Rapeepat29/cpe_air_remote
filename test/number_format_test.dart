import 'package:cpe_air_remote/utils/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats decimal values with thousands separators', () {
    expect(formatDecimal(4.5), '4.50');
    expect(formatDecimal(1217.25), '1,217.25');
    expect(formatDecimal(270.5 * 5.25), '1,420.13');
  });
}
