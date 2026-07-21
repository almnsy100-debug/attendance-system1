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

  static pw.Widget _barcode(String value) {
    return pw.BarcodeWidget(
      barcode: pw.Barcode.code128(),
      data: value,
      width: 150,
      height: 34,
      drawText: false,
    );
  }

  static pw.Widget _line(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(
        '$label: ${value.isEmpty ? '-' : value}',
        style: pw.TextStyle(font: font, fontSize: 8),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  static Future<Uint8List> cartonLabel({
    required ProductRecord product,
    required LotRecord lot,
    required CartonRecord carton,
    int copies = 1,
  }) async {
    final pw.Font font = await _font();
    final pw.Document document = pw.Document();
    final PdfPageFormat format = PdfPageFormat(
      100 * PdfPageFormat.mm,
      70 * PdfPageFormat.mm,
      marginAll: 5 * PdfPageFormat.mm,
    );

    for (int index = 0; index < copies; index++) {
      document.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: <pw.Widget>[
                pw.Text(
                  'SmartChem Track • CARTON',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                _line('المنتج / Product', product.name, font),
                _line('SKU', product.sku, font),
                _line('LOT', lot.lotNumber, font),
                _line('EXP', _date(lot.manufacturerExpiry), font),
                _line('العلب / Units', carton.actualUnitCount.toString(), font),
                pw.Spacer(),
                pw.Center(child: _barcode(carton.cartonCode)),
                pw.SizedBox(height: 2),
                pw.Text(
                  carton.cartonCode,
                  style: pw.TextStyle(font: font, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            );
          },
        ),
      );
    }

    return document.save();
  }

  static Future<Uint8List> unitLabels({
    required ProductRecord product,
    required List<UnitRecord> units,
    int copies = 1,
  }) async {
    final pw.Font font = await _font();
    final pw.Document document = pw.Document();
    final PdfPageFormat format = PdfPageFormat(
      60 * PdfPageFormat.mm,
      40 * PdfPageFormat.mm,
      marginAll: 3 * PdfPageFormat.mm,
    );

    for (final UnitRecord unit in units) {
      for (int index = 0; index < copies; index++) {
        document.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: <pw.Widget>[
                  pw.Text(
                    product.name,
                    maxLines: 1,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  _line('LOT', unit.lotNumber, font),
                  _line('EXP', _date(unit.manufacturerExpiry), font),
                  _line(
                    'الفتح / Open',
                    unit.openedAt == null ? '-' : _date(unit.openedAt),
                    font,
                  ),
                  _line(
                    'بعد الفتح / BUD',
                    unit.afterOpenExpiry == null
                        ? '${unit.afterOpenDays} days'
                        : _date(unit.afterOpenExpiry),
                    font,
                  ),
                  pw.Spacer(),
                  pw.Center(child: _barcode(unit.unitCode)),
                  pw.Text(
                    unit.unitCode,
                    style: pw.TextStyle(font: font, fontSize: 6),
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

  static String _date(DateTime? value) {
    if (value == null) return '-';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
