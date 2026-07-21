import 'package:flutter_test/flutter_test.dart';
import 'package:production/main.dart';

void main() {
  test('Parse parenthesized GS1 barcode', () {
    final ParsedGs1 parsed = parseGs1(
      '(01)00380740150005'
      '(17)260731'
      '(10)50532Y600'
      '(21)SER123'
      '(240)09P9510',
    );

    expect(parsed.gtin, '00380740150005');

    expect(parsed.lot, '50532Y600');

    expect(parsed.serial, 'SER123');

    expect(parsed.catalog, '09P9510');

    expect(parsed.expiryDate, DateTime(2026, 7, 31));
  });
}
