import 'package:flutter_test/flutter_test.dart';
import 'package:production/label_service.dart';
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

  test('printed label data is GS1 DataMatrix ECC 200 with required AIs', () {
    final String readable = InventoryLabelService.gs1HumanReadable(
      gtin: '00380740150005',
      lotNumber: 'LOT-A',
      catalogNumber: '09P9510',
      serialNumber: 'ALT2-84441UD00-001',
      manufacturerExpiry: DateTime(2027, 1, 31),
    );
    final ParsedGs1 parsed = parseGs1(readable);
    expect(parsed.gtin, '00380740150005');
    expect(parsed.lot, 'LOT-A');
    expect(parsed.catalog, '09P9510');
    expect(parsed.serial, 'ALT2-84441UD00-001');
    expect(parsed.expiryDate, DateTime(2027, 1, 31));

    final payload = InventoryLabelService.gs1DataMatrixPayload(
      gtin: '00380740150005',
      lotNumber: 'LOT-A',
      catalogNumber: '09P9510',
      serialNumber: 'ALT2-84441UD00-001',
      manufacturerExpiry: DateTime(2027, 1, 31),
    );
    expect(payload, isNotEmpty);
    expect(payload.first, 0xe8, reason: 'Data Matrix must start with FNC1');
  });
}
