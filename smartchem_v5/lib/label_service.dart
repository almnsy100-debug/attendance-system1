import 'dart:convert';
import 'dart:io';

import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'inventory_models.dart';

class InventoryLabelService {
  static final PdfPageFormat cartonLabelFormat = PdfPageFormat(
    100 * PdfPageFormat.mm,
    75 * PdfPageFormat.mm,
    marginAll: 3 * PdfPageFormat.mm,
  );

  static final PdfPageFormat unitLabelFormat = PdfPageFormat(
    60 * PdfPageFormat.mm,
    100 * PdfPageFormat.mm,
    marginAll: 2.5 * PdfPageFormat.mm,
  );

  static Future<pw.Font> _arabicFont() async {
    final ByteData bytes = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );
    return pw.Font.ttf(bytes);
  }

  static String _compactInternalData(Map<String, String> fields) {
    final Map<String, String> compact = <String, String>{
      for (final MapEntry<String, String> entry in fields.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };
    final List<int> compressed = GZipCodec(
      level: 9,
    ).encode(utf8.encode(jsonEncode(compact)));
    return 'GZ1${base64UrlEncode(compressed)}';
  }

  static List<String> _internalChunks(Map<String, String> fields) {
    final String encoded = _compactInternalData(fields);
    const int chunkLength = 78;
    final List<String> chunks = <String>[];
    for (int start = 0; start < encoded.length; start += chunkLength) {
      final int end =
          start + chunkLength < encoded.length
              ? start + chunkLength
              : encoded.length;
      chunks.add(encoded.substring(start, end));
    }
    if (chunks.length > 9) {
      throw StateError('GS1_INTERNAL_DATA_TOO_LARGE');
    }
    return chunks;
  }

  static Uint8List gs1DataMatrixPayload({
    required String gtin,
    required String lotNumber,
    required String catalogNumber,
    required String serialNumber,
    DateTime? manufacturerExpiry,
    Map<String, String> internalData = const <String, String>{},
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

    final List<String> variables = <String>[];
    if (lotNumber.trim().isNotEmpty) {
      variables.add('10${lotNumber.trim()}');
    }
    if (catalogNumber.trim().isNotEmpty) {
      variables.add('240${catalogNumber.trim()}');
    }
    variables.add('21${serialNumber.trim()}');
    final List<String> chunks = _internalChunks(internalData);
    for (int index = 0; index < chunks.length; index++) {
      variables.add('${91 + index}${chunks[index]}');
    }
    for (int index = 0; index < variables.length; index++) {
      encoder.ascii(variables[index]);
      if (index < variables.length - 1) encoder.gs();
    }
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

  static Map<String, String> _internalData({
    required ProductRecord product,
    required LotRecord lot,
    required CartonRecord carton,
    UnitRecord? unit,
    List<UnitRecord> cartonUnits = const <UnitRecord>[],
  }) {
    final UnitRecord? quantitySource =
        unit ?? (cartonUnits.isEmpty ? null : cartonUnits.first);
    return <String, String>{
      'n': product.name,
      'sku': product.sku,
      'typ': product.type,
      'raw': carton.sourceBarcode,
      'fmt': carton.barcodeFormat,
      'abb': product.abbottListNo,
      'moh': product.mohCode,
      'dep': product.department,
      'dev': product.deviceName,
      'sto': product.storageLocation,
      'rec': _date(lot.receivedAt),
      'car': carton.cartonCode,
      'qty':
          quantitySource == null
              ? ''
              : '${_number(quantitySource.originalQuantity)}'
                  ' ${quantitySource.measureUnit}',
      'stb': _stability(product),
      if (unit != null) ...<String, String>{
        'unt': unit.unitCode,
        'opn': _dateTime(unit.openedAt),
        'bud': _dateTime(unit.afterOpenExpiry),
        'rem': '${_number(unit.remainingQuantity)} ${unit.measureUnit}',
      },
      if (cartonUnits.isNotEmpty) ...<String, String>{
        'uf': cartonUnits.first.unitCode,
        'ul': cartonUnits.last.unitCode,
        'uc': cartonUnits.length.toString(),
      },
    };
  }

  static pw.Widget _dataMatrix({
    required ProductRecord product,
    required LotRecord lot,
    required CartonRecord carton,
    required String serialNumber,
    UnitRecord? unit,
    List<UnitRecord> cartonUnits = const <UnitRecord>[],
    required double size,
  }) {
    return pw.BarcodeWidget.fromBytes(
      barcode: pw.Barcode.dataMatrix(),
      data: gs1DataMatrixPayload(
        gtin: product.gtin,
        lotNumber: lot.lotNumber,
        catalogNumber: product.catalogNumber,
        serialNumber: serialNumber,
        manufacturerExpiry: lot.manufacturerExpiry,
        internalData: _internalData(
          product: product,
          lot: lot,
          carton: carton,
          unit: unit,
          cartonUnits: cartonUnits,
        ),
      ),
      width: size,
      height: size,
      drawText: false,
    );
  }

  static String _display(String label, Object? value) {
    final String rendered = value?.toString().trim() ?? '';
    return '$label: ${rendered.isEmpty ? '-' : rendered}';
  }

  static pw.Widget _line(
    String label,
    Object? value, {
    double fontSize = 5.3,
    int maxLines = 1,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Text(
        _display(label, value),
        maxLines: maxLines,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          lineSpacing: 0.4,
        ),
        textDirection: pw.TextDirection.ltr,
      ),
    );
  }

  static List<pw.Widget> _coreLines({
    required ProductRecord product,
    required LotRecord lot,
    required CartonRecord carton,
    UnitRecord? unit,
  }) {
    return <pw.Widget>[
      _line('Product', product.name, bold: true),
      _line('Internal No', product.sku),
      _line('Type', product.type),
      _line('GTIN', product.gtin),
      _line('Raw barcode', carton.sourceBarcode),
      _line('Barcode format', carton.barcodeFormat),
      _line('Abbott List No', product.abbottListNo),
      _line('MOH Code', product.mohCode),
      _line('Catalog No', product.catalogNumber),
      _line('LOT', lot.lotNumber),
      _line('Receipt date', _date(lot.receivedAt)),
      _line('Manufacturer expiry', _date(lot.manufacturerExpiry)),
      _line('Department', product.department),
      _line('Device', product.deviceName),
      _line('Storage', product.storageLocation),
      _line('Stability after opening', _stability(product)),
      if (unit != null) ...<pw.Widget>[
        _line(
          'Original quantity',
          '${_number(unit.originalQuantity)} ${unit.measureUnit}',
        ),
        _line(
          'Remaining',
          '${_number(unit.remainingQuantity)} ${unit.measureUnit}',
        ),
        _line('Opened at', _dateTime(unit.openedAt)),
        _line(
          'After-open expiry',
          unit.afterOpenExpiry == null
              ? _stabilityFromUnit(unit)
              : _dateTime(unit.afterOpenExpiry),
        ),
      ],
    ];
  }

  static pw.ThemeData _theme(pw.Font arabicFont) {
    return pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      fontFallback: <pw.Font>[arabicFont],
    );
  }

  static Future<Uint8List> cartonLabel({
    required ProductRecord product,
    required LotRecord lot,
    required CartonRecord carton,
    required List<UnitRecord> units,
    int copies = 1,
  }) async {
    final pw.Font arabicFont = await _arabicFont();
    final pw.Document document = pw.Document(theme: _theme(arabicFont));
    const int codesPerPage = 12;
    final int pageCount =
        units.isEmpty ? 1 : (units.length / codesPerPage).ceil();

    for (int copy = 0; copy < copies; copy++) {
      for (int page = 0; page < pageCount; page++) {
        final List<UnitRecord> pageUnits =
            units.skip(page * codesPerPage).take(codesPerPage).toList();
        document.addPage(
          pw.Page(
            pageFormat: cartonLabelFormat,
            build:
                (pw.Context context) => pw.Stack(
                  children: <pw.Widget>[
                    pw.Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      child: pw.SizedBox(
                        height: 13,
                        child: pw.Text(
                          'SmartChem Track | GS1 DataMatrix ECC 200 | CARTON '
                          '${page + 1}/$pageCount',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                    pw.Positioned(
                      left: 0,
                      top: 15,
                      child: pw.SizedBox(
                        width: 166,
                        height: 126,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: <pw.Widget>[
                            ..._coreLines(
                              product: product,
                              lot: lot,
                              carton: carton,
                            ),
                            _line(
                              'Unit quantity',
                              units.isEmpty
                                  ? '-'
                                  : '${_number(units.first.originalQuantity)} '
                                      '${units.first.measureUnit}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.Positioned(
                      right: 0,
                      top: 17,
                      child: pw.SizedBox(
                        width: 91,
                        height: 116,
                        child: pw.Column(
                          children: <pw.Widget>[
                            _dataMatrix(
                              product: product,
                              lot: lot,
                              carton: carton,
                              serialNumber: carton.cartonCode,
                              cartonUnits: units,
                              size: 82,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              carton.cartonCode,
                              style: pw.TextStyle(
                                fontSize: 6.2,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                              maxLines: 2,
                            ),
                            pw.Text(
                              'Units: ${units.length}',
                              style: const pw.TextStyle(fontSize: 5.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.Positioned(
                      left: 0,
                      right: 0,
                      top: 144,
                      child: pw.SizedBox(
                        height: 43,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.only(top: 3),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(color: PdfColors.grey600),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            children: <pw.Widget>[
                              pw.Text(
                                'Unit serials (${page + 1}/$pageCount)',
                                style: pw.TextStyle(
                                  fontSize: 5.7,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                              pw.Wrap(
                                spacing: 4,
                                runSpacing: 1,
                                children:
                                    pageUnits
                                        .map(
                                          (UnitRecord unit) => pw.SizedBox(
                                            width: 83,
                                            child: pw.Text(
                                              unit.unitCode,
                                              style: const pw.TextStyle(
                                                fontSize: 4.8,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    pw.Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: pw.SizedBox(
                        height: 7,
                        child: pw.Text(
                          gs1HumanReadable(
                            gtin: product.gtin,
                            lotNumber: lot.lotNumber,
                            catalogNumber: product.catalogNumber,
                            serialNumber: carton.cartonCode,
                            manufacturerExpiry: lot.manufacturerExpiry,
                          ),
                          style: const pw.TextStyle(fontSize: 4.2),
                          textAlign: pw.TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
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
    final pw.Font arabicFont = await _arabicFont();
    final pw.Document document = pw.Document(theme: _theme(arabicFont));

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
            pageFormat: unitLabelFormat,
            build:
                (pw.Context context) => pw.Stack(
                  children: <pw.Widget>[
                    pw.Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      child: pw.SizedBox(
                        height: 13,
                        child: pw.Text(
                          'SmartChem Track | GS1 DataMatrix | UNIT',
                          style: pw.TextStyle(
                            fontSize: 7.1,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                    pw.Positioned(
                      left: 0,
                      top: 15,
                      right: 0,
                      child: pw.SizedBox(
                        height: 139,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: <pw.Widget>[
                            ..._coreLines(
                              product: product,
                              lot: lot,
                              carton: carton,
                              unit: unit,
                            ).map(
                              (pw.Widget line) =>
                                  pw.SizedBox(height: 6.5, child: line),
                            ),
                            _line(
                              'Carton serial',
                              unit.cartonCode,
                              fontSize: 5.1,
                            ),
                            _line(
                              'Unit serial',
                              unit.unitCode,
                              fontSize: 5.1,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.Positioned(
                      left: 0,
                      bottom: 9,
                      child: pw.SizedBox(
                        width: 82,
                        height: 82,
                        child: _dataMatrix(
                          product: product,
                          lot: lot,
                          carton: carton,
                          serialNumber: unit.unitCode,
                          unit: unit,
                          size: 80,
                        ),
                      ),
                    ),
                    pw.Positioned(
                      left: 87,
                      right: 0,
                      bottom: 19,
                      child: pw.SizedBox(
                        height: 64,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: <pw.Widget>[
                            pw.Text(
                              unit.unitCode,
                              style: pw.TextStyle(
                                fontSize: 7.2,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              maxLines: 3,
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              '${_number(unit.originalQuantity)} '
                              '${unit.measureUnit}',
                              style: pw.TextStyle(
                                fontSize: 7.2,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'LOT ${unit.lotNumber}\n'
                              'EXP ${_date(unit.manufacturerExpiry)}',
                              style: const pw.TextStyle(fontSize: 5.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: pw.SizedBox(
                        height: 7,
                        child: pw.Text(
                          gs1HumanReadable(
                            gtin: product.gtin,
                            lotNumber: unit.lotNumber,
                            catalogNumber: product.catalogNumber,
                            serialNumber: unit.unitCode,
                            manufacturerExpiry: unit.manufacturerExpiry,
                          ),
                          style: const pw.TextStyle(fontSize: 3.8),
                          textAlign: pw.TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
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
