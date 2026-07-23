import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_util;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'inventory_models.dart';

class InventoryExportService {
  static const List<String> headers = <String>[
    'Product',
    'Internal No',
    'Type',
    'GTIN',
    'Raw barcode',
    'Barcode format',
    'Abbott List No',
    'MOH Code',
    'Catalog No',
    'LOT',
    'Receipt date',
    'Manufacturer expiry',
    'Department',
    'Device',
    'Storage',
    'Carton serial',
    'Unit serial',
    'Original quantity',
    'Used quantity',
    'Remaining quantity',
    'Measure unit',
    'Opened at',
    'After-open expiry',
    'Status',
  ];

  static List<String> _values(UnitRecord unit) {
    return <String>[
      unit.productName,
      unit.productSku,
      unit.productType,
      unit.gtin,
      unit.cartonSourceBarcode,
      unit.barcodeFormat,
      unit.abbottListNo,
      unit.mohCode,
      unit.catalogNumber,
      unit.lotNumber,
      _date(unit.receivedAt),
      _date(unit.manufacturerExpiry),
      unit.department,
      unit.deviceName,
      unit.storageLocation,
      unit.cartonCode,
      unit.unitCode,
      _number(unit.originalQuantity),
      _number(unit.usedQuantity),
      _number(unit.remainingQuantity),
      unit.measureUnit,
      _dateTime(unit.openedAt),
      _dateTime(unit.afterOpenExpiry),
      unit.isExpired ? 'expired' : unit.status,
    ];
  }

  static Uint8List excelBytes(List<UnitRecord> units) {
    final xls.Excel workbook = xls.Excel.createExcel();
    final xls.Sheet sheet = workbook['Inventory'];
    sheet.isRTL = true;
    sheet.appendRow(headers.map<xls.CellValue>(xls.TextCellValue.new).toList());
    for (final UnitRecord unit in units) {
      sheet.appendRow(
        _values(unit).map<xls.CellValue>(xls.TextCellValue.new).toList(),
      );
    }
    workbook.delete('Sheet1');
    final List<int>? bytes = workbook.save();
    if (bytes == null) throw StateError('EXCEL_EXPORT_FAILED');
    return Uint8List.fromList(bytes);
  }

  static Future<void> shareExcel(
    List<UnitRecord> units, {
    required String filename,
  }) async {
    final Directory directory = await getTemporaryDirectory();
    final File file = File(path_util.join(directory.path, filename));
    await file.writeAsBytes(excelBytes(units), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'SmartChem Track inventory export',
      ),
    );
  }

  static Future<Uint8List> pdfBytes(List<UnitRecord> units) async {
    final ByteData fontBytes = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );
    final pw.Font font = pw.Font.ttf(fontBytes);
    final pw.Document document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: <pw.Font>[pw.Font.helvetica()],
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header:
            (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: <pw.Widget>[
                pw.Text(
                  'SmartChem Track - Product / LOT / Carton / Unit',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated: ${_dateTime(DateTime.now())} | '
                  'Records: ${units.length}',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.SizedBox(height: 8),
              ],
            ),
        footer:
            (pw.Context context) => pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(font: font, fontSize: 8),
              ),
            ),
        build:
            (pw.Context context) =>
                units.map<pw.Widget>((UnitRecord unit) {
                  final List<String> values = _values(unit);
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(7),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: <pw.Widget>[
                        pw.Text(
                          '${unit.productName} - ${unit.unitCode}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: <pw.Widget>[
                            for (int index = 0; index < headers.length; index++)
                              pw.SizedBox(
                                width: 245,
                                child: pw.Text(
                                  '${headers[index]}: '
                                  '${values[index].isEmpty ? '-' : values[index]}',
                                  style: pw.TextStyle(
                                    font: font,
                                    fontSize: 6.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
      ),
    );
    return document.save();
  }

  static String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  static String _date(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _dateTime(DateTime? value) {
    if (value == null) return '';
    return '${_date(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
