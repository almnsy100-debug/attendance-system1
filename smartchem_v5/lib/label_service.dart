import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'inventory_models.dart';

class InventoryLabelService {
  static Future<pw.Font> _font() async {
    final ByteData bytes = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );
    return pw.Font.ttf(bytes);
  }

  static Uint8List gs1DataMatrixPayload({
    required String gtin,
    required String lotNumber,
    required String catalogNumber,
    required String serialNumber,
    DateTime? manufacturerExpiry,
  }) {
    final DataMatrixEncoder encoder = DataMatrixEncoder()..fnc1();
    final String normalizedGtin = gtin.replaceAll(RegExp(r'\D'), '');
    if (normalizedGtin.length == 14) {
      encoder.ascii('01$normalizedGtin');
    }
    if (manufacturerExpiry != null) {
      encoder.ascii(
        '17${(manufacturerExpiry.year % 100).toString().padLeft(2, '0')}'
        '${manufacturerExpiry.month.toString().padLeft(2, '0')}'
        '${manufacturerExpiry.day.toString().padLeft(2, '0')}',
      );
    }
    if (lotNumber.trim().isNotEmpty) {
      encoder
        ..ascii('10${lotNumber.trim()}')
        ..gs();
    }
    if (catalogNumber.trim().isNotEmpty) {
      encoder
        ..ascii('240${catalogNumber.trim()}')
        ..gs();
    }
    encoder.ascii('21${serialNumber.trim()}');
    return encoder.toBytes();
  }

  static String gs1HumanReadable({
    required String gtin,
    required String lotNumber,
    required String catalogNumber,
    required String serialNumber,
    DateTime? manufacturerExpiry,
  }) {
    final StringBuffer value = StringBuffer();
    final String normalizedGtin = gtin.replaceAll(RegExp(r'\D'), '');
    if (normalizedGtin.length == 14) value.write('(01)$normalizedGtin');
    if (manufacturerExpiry != null) {
      value.write(
        '(17)${(manufacturerExpiry.year % 100).toString().padLeft(2, '0')}'
        '${manufacturerExpiry.month.toString().padLeft(2, '0')}'
        '${manufacturerExpiry.day.toString().padLeft(2, '0')}',
      );
    }
    if (lotNumber.trim().isNotEmpty) value.write('(10)${lotNumber.trim()}');
    if (catalogNumber.trim().isNotEmpty) {
      value.write('(240)${catalogNumber.trim()}');
    }
    value.write('(21)${serialNumber.trim()}');
    return value.toString();
  }

  static pw.Widget _dataMatrix({
    required ProductRecord product,
    required String lotNumber,
    required String serialNumber,
    required DateTime? manufacturerExpiry,
    double size = 88,
  }) {
    return pw.BarcodeWidget.fromBytes(
      barcode: pw.Barcode.dataMatrix(),
      data: gs1DataMatrixPayload(
        gtin: product.gtin,
        lotNumber: lotNumber,
        catalogNumber: product.catalogNumber,
        serialNumber: serialNumber,
        manufacturerExpiry: manufacturerExpiry,
      ),
      width: size,
      height: size,
      drawText: false,
    );
  }

  static pw.Widget _line(
    String label,
    Object? value,
    pw.Font font, {
    double fontSize = 7,
  }) {
    final String rendered = value?.toString().trim() ?? '';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.4),
      child: pw.Text(
        '$label: ${rendered.isEmpty ? '-' : rendered}',
        style: pw.TextStyle(font: font, fontSize: fontSize),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  static List<pw.Widget> _registeredProductLines({
    required ProductRecord product,
    required LotRecord lot,
    required CartonRecord carton,
    required pw.Font font,
    UnitRecord? unit,
  }) {
    return <pw.Widget>[
      _line('اسم المادة / Product', product.name, font),
      _line('الرقم الداخلي / Internal No', product.sku, font),
      _line('النوع / Type', product.type, font),
      _line('GTIN', product.gtin, font),
      _line('القيمة الأصلية / Raw barcode', carton.sourceBarcode, font),
      _line('Barcode format', carton.barcodeFormat, font),
      _line('Abbott List No', product.abbottListNo, font),
      _line('MOH Code', product.mohCode, font),
      _line('رقم الكتالوج / Catalog', product.catalogNumber, font),
      _line('LOT', lot.lotNumber, font),
      _line('تاريخ الاستلام / Received', _date(lot.receivedAt), font),
      _line(
        'انتهاء الشركة / Manufacturer EXP',
        _date(lot.manufacturerExpiry),
        font,
      ),
      _line('القسم / Department', product.department, font),
      _line('الجهاز / Device', product.deviceName, font),
      _line('التخزين / Storage', product.storageLocation, font),
      if (unit != null)
        _line(
          'كمية العلبة / Unit quantity',
          '${_number(unit.originalQuantity)} ${unit.measureUnit}',
          font,
        ),
      _line('الثبات بعد الفتح / Stability', _stability(product), font),
    ];
  }

  static Future<Uint8List> cartonLabel({
    required ProductRecord product,
    required LotRecord lot,
    required CartonRecord carton,
    required List<UnitRecord> units,
    int copies = 1,
  }) async {
    final pw.Font font = await _font();
    final pw.Document document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: <pw.Font>[pw.Font.helvetica()],
      ),
    );
    final PdfPageFormat format = PdfPageFormat(
      100 * PdfPageFormat.mm,
      130 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    );
    const int codesPerPage = 18;
    final int pageCount =
        units.isEmpty ? 1 : (units.length / codesPerPage).ceil();

    for (int copy = 0; copy < copies; copy++) {
      for (int page = 0; page < pageCount; page++) {
        final int start = page * codesPerPage;
        final List<UnitRecord> pageUnits =
            units.skip(start).take(codesPerPage).toList();
        document.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: <pw.Widget>[
                  pw.Text(
                    'SmartChem Track | GS1 DataMatrix ECC 200 | CARTON '
                    '${page + 1}/$pageCount',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: _registeredProductLines(
                            product: product,
                            lot: lot,
                            carton: carton,
                            font: font,
                            unit: units.isEmpty ? null : units.first,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Column(
                        children: <pw.Widget>[
                          _dataMatrix(
                            product: product,
                            lotNumber: lot.lotNumber,
                            serialNumber: carton.cartonCode,
                            manufacturerExpiry: lot.manufacturerExpiry,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            carton.cartonCode,
                            style: pw.TextStyle(font: font, fontSize: 7),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(),
                  _line(
                    'مسلسل الكرتون / Carton serial',
                    carton.cartonCode,
                    font,
                    fontSize: 8,
                  ),
                  _line('عدد العلب / Units', units.length, font, fontSize: 8),
                  pw.Text(
                    'مسلسلات العلب / Unit serials',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children:
                        pageUnits
                            .map(
                              (UnitRecord unit) => pw.SizedBox(
                                width: 122,
                                child: pw.Text(
                                  '- ${unit.unitCode}',
                                  style: pw.TextStyle(
                                    font: font,
                                    fontSize: 6.5,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    gs1HumanReadable(
                      gtin: product.gtin,
                      lotNumber: lot.lotNumber,
                      catalogNumber: product.catalogNumber,
                      serialNumber: carton.cartonCode,
                      manufacturerExpiry: lot.manufacturerExpiry,
                    ),
                    style: pw.TextStyle(font: font, fontSize: 5),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              );
            },
          ),
        );
      }
    }
    return document.save();
  }

  static Future<Uint8List> unitLabels({
    required ProductRecord product,
    required List<UnitRecord> units,
    int copies = 1,
  }) async {
    final pw.Font font = await _font();
    final pw.Document document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: <pw.Font>[pw.Font.helvetica()],
      ),
    );
    final PdfPageFormat format = PdfPageFormat(
      100 * PdfPageFormat.mm,
      90 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    );

    for (final UnitRecord unit in units) {
      final LotRecord lot = LotRecord(
        id: unit.lotId,
        productId: unit.productId,
        productName: unit.productName,
        lotNumber: unit.lotNumber,
        manufacturerExpiry: unit.manufacturerExpiry,
        receivedAt: unit.receivedAt,
        status: 'active',
        cartonCount: 1,
        unitCount: 1,
        createdAt: unit.createdAt,
      );
      final CartonRecord carton = CartonRecord(
        id: unit.cartonId,
        lotId: unit.lotId,
        productId: unit.productId,
        productName: unit.productName,
        lotNumber: unit.lotNumber,
        manufacturerExpiry: unit.manufacturerExpiry,
        cartonCode: unit.cartonCode,
        sourceBarcode: unit.cartonSourceBarcode,
        barcodeFormat: unit.barcodeFormat,
        sequenceNumber: 1,
        expectedUnitCount: 1,
        actualUnitCount: 1,
        openUnitCount: unit.isOpened ? 1 : 0,
        status: 'active',
        createdAt: unit.createdAt,
        lastPrintedAt: null,
      );
      for (int copy = 0; copy < copies; copy++) {
        document.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: <pw.Widget>[
                  pw.Text(
                    'SmartChem Track | GS1 DataMatrix ECC 200 | UNIT',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: <pw.Widget>[
                            ..._registeredProductLines(
                              product: product,
                              lot: lot,
                              carton: carton,
                              font: font,
                              unit: unit,
                            ),
                            _line(
                              'تاريخ الفتح / Opened',
                              _dateTime(unit.openedAt),
                              font,
                            ),
                            _line(
                              'انتهاء بعد الفتح / BUD',
                              unit.afterOpenExpiry == null
                                  ? _stabilityFromUnit(unit)
                                  : _dateTime(unit.afterOpenExpiry),
                              font,
                            ),
                            _line(
                              'المتبقي / Remaining',
                              '${_number(unit.remainingQuantity)} '
                                  '${unit.measureUnit}',
                              font,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Column(
                        children: <pw.Widget>[
                          _dataMatrix(
                            product: product,
                            lotNumber: unit.lotNumber,
                            serialNumber: unit.unitCode,
                            manufacturerExpiry: unit.manufacturerExpiry,
                            size: 92,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            unit.unitCode,
                            style: pw.TextStyle(font: font, fontSize: 6.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  _line(
                    'مسلسل الكرتون / Carton serial',
                    unit.cartonCode,
                    font,
                    fontSize: 7,
                  ),
                  _line(
                    'مسلسل العلبة / Unit serial',
                    unit.unitCode,
                    font,
                    fontSize: 7,
                  ),
                  pw.Text(
                    gs1HumanReadable(
                      gtin: product.gtin,
                      lotNumber: unit.lotNumber,
                      catalogNumber: product.catalogNumber,
                      serialNumber: unit.unitCode,
                      manufacturerExpiry: unit.manufacturerExpiry,
                    ),
                    style: pw.TextStyle(font: font, fontSize: 5),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              );
            },
          ),
        );
      }
    }
    return document.save();
  }

  static String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  static String _date(DateTime? value) {
    if (value == null) return '-';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _dateTime(DateTime? value) {
    if (value == null) return '-';
    return '${_date(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  static String _stability(ProductRecord product) {
    if (!product.stabilityEnabled || product.stabilityValue <= 0) return '-';
    return '${product.stabilityValue} ${product.stabilityPeriod}';
  }

  static String _stabilityFromUnit(UnitRecord unit) {
    if (!unit.stabilityEnabled || unit.stabilityValue <= 0) return '-';
    return '${unit.stabilityValue} ${unit.stabilityPeriod}';
  }
}
