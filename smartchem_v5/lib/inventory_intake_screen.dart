import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'inventory_models.dart';
import 'inventory_repository.dart';
import 'inventory_text.dart';

class InventoryIntakeScreen extends StatefulWidget {
  const InventoryIntakeScreen({
    super.key,
    required this.repository,
    required this.actorId,
    required this.rawBarcode,
    required this.barcodeFormat,
    required this.gtin,
    required this.lotNumber,
    required this.serialNumber,
    required this.catalogNumber,
    required this.manufacturerExpiry,
  });

  final InventoryRepository repository;
  final int actorId;
  final String rawBarcode;
  final String barcodeFormat;
  final String gtin;
  final String lotNumber;
  final String serialNumber;
  final String catalogNumber;
  final DateTime? manufacturerExpiry;

  @override
  State<InventoryIntakeScreen> createState() => _InventoryIntakeScreenState();
}

class _InventoryIntakeScreenState extends State<InventoryIntakeScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController internalNumber = TextEditingController();
  final TextEditingController cartonCode = TextEditingController();
  final TextEditingController abbottListNo = TextEditingController();
  final TextEditingController mohCode = TextEditingController();
  final TextEditingController unitCount = TextEditingController();
  final TextEditingController stabilityValue = TextEditingController();
  final TextEditingController otherType = TextEditingController();
  final TextEditingController otherDepartment = TextEditingController();
  final TextEditingController otherDevice = TextEditingController();
  final TextEditingController otherStorage = TextEditingController();
  final TextEditingController otherMeasureUnit = TextEditingController();

  List<ProductCatalogRecord> catalog = <ProductCatalogRecord>[];
  ProductCatalogRecord? selectedMaterial;
  String materialType = 'Reagent';
  String department = 'Chemistry';
  String device = 'Alinity';
  String storage = 'Fridge #1';
  String measureUnit = 'mL';
  String stabilityPeriod = 'hour';
  bool stabilityEnabled = false;
  bool loading = true;
  bool saving = false;
  String generatedInternalNumber = '';

  static const String otherValue = '__other__';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final String next = await widget.repository.nextInternalNumber();
      final String code = await widget.repository.suggestCartonCode(
        preferred: widget.serialNumber,
        internalNumber: next,
        lotNumber: widget.lotNumber,
      );
      final List<ProductCatalogRecord> entries =
          await widget.repository.productCatalog();
      if (!mounted) return;
      setState(() {
        generatedInternalNumber = next;
        internalNumber.text = next;
        cartonCode.text = code;
        catalog = entries;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      _showError(error);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      internalNumber,
      cartonCode,
      abbottListNo,
      mohCode,
      unitCount,
      stabilityValue,
      otherType,
      otherDepartment,
      otherDevice,
      otherStorage,
      otherMeasureUnit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _date(DateTime? value, {bool includeTime = false}) {
    if (value == null) return '';
    final String date =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    if (!includeTime) return date;
    return '$date '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _selected(String value, TextEditingController other) {
    return value == otherValue ? other.text.trim() : value;
  }

  String _optionValue(
    String value,
    List<String> choices,
    TextEditingController other, {
    required String fallback,
  }) {
    if (value.trim().isEmpty) return fallback;
    if (choices.contains(value)) return value;
    other.text = value;
    return otherValue;
  }

  Future<void> _selectMaterial(ProductCatalogRecord? value) async {
    setState(() {
      selectedMaterial = value;
      abbottListNo.text = value?.abbottListNo ?? '';
      mohCode.text = value?.mohCode ?? '';
    });
    if (value == null) return;
    final ProductRecord? existing = await widget.repository.productForCatalog(
      value,
    );
    if (!mounted || selectedMaterial?.id != value.id) return;
    setState(() {
      if (existing == null) {
        internalNumber.text = generatedInternalNumber;
        otherType.clear();
        otherDepartment.clear();
        otherDevice.clear();
        otherStorage.clear();
        otherMeasureUnit.clear();
        materialType = 'Reagent';
        department = 'Chemistry';
        device = 'Alinity';
        storage = 'Fridge #1';
        measureUnit = 'mL';
        stabilityEnabled = false;
        stabilityValue.clear();
        stabilityPeriod = 'hour';
      } else {
        internalNumber.text = existing.sku;
        materialType = _optionValue(
          existing.type,
          const <String>['Reagent', 'Control', 'Calibrator', 'Consumable'],
          otherType,
          fallback: 'Reagent',
        );
        department = _optionValue(
          existing.department,
          const <String>['Chemistry'],
          otherDepartment,
          fallback: 'Chemistry',
        );
        device = _optionValue(
          existing.deviceName,
          const <String>['Alinity'],
          otherDevice,
          fallback: 'Alinity',
        );
        storage = _optionValue(
          existing.storageLocation,
          const <String>['Fridge #1', 'Fridge #2', 'Fridge #3', 'Fridge #4'],
          otherStorage,
          fallback: 'Fridge #1',
        );
        measureUnit = _optionValue(
          existing.defaultUnit,
          const <String>[
            'mL',
            'Tests',
            'Vials',
            'Bottles',
            'Cartridges',
            'Packs',
          ],
          otherMeasureUnit,
          fallback: 'mL',
        );
        stabilityEnabled = existing.stabilityEnabled;
        stabilityValue.text =
            existing.stabilityEnabled ? existing.stabilityValue.toString() : '';
        stabilityPeriod =
            inventoryStabilityPeriods.contains(existing.stabilityPeriod)
                ? existing.stabilityPeriod
                : 'day';
      }
    });
    final String code = await widget.repository.suggestCartonCode(
      preferred: widget.serialNumber,
      internalNumber: internalNumber.text,
      lotNumber: widget.lotNumber,
    );
    if (!mounted || selectedMaterial?.id != value.id) return;
    setState(() => cartonCode.text = code);
  }

  String _normalizeHeader(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-./#():]+'), '');
  }

  Future<void> _importCatalog() async {
    const XTypeGroup excelTypeGroup = XTypeGroup(
      label: 'Excel workbook',
      extensions: <String>['xlsx'],
      mimeTypes: <String>[
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
    );
    final XFile? selectedFile = await openFile(
      acceptedTypeGroups: <XTypeGroup>[excelTypeGroup],
    );
    if (selectedFile == null) return;

    try {
      final Uint8List bytes = await selectedFile.readAsBytes();
      final xls.Excel workbook = xls.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) throw StateError('EMPTY_EXCEL_FILE');
      final xls.Sheet sheet = workbook.tables.values.first;
      if (sheet.rows.isEmpty) throw StateError('EMPTY_EXCEL_FILE');
      final List<String> headers =
          sheet.rows.first
              .map(
                (xls.Data? cell) =>
                    _normalizeHeader(cell?.value.toString() ?? ''),
              )
              .toList();

      int column(List<String> aliases) {
        final Set<String> normalized = aliases.map(_normalizeHeader).toSet();
        return headers.indexWhere(normalized.contains);
      }

      final int nameIndex = column(<String>[
        'Material Name',
        'Product Name',
        'Name',
        'Item Description',
        'Description',
        'اسم المادة',
        'المادة',
      ]);
      final int abbottIndex = column(<String>[
        'Abbott List No',
        'Abbott List Number',
        'Abbott No',
        'List No',
        'List Number',
      ]);
      final int mohIndex = column(<String>[
        'MOH Code',
        'MOH Number',
        'Ministry of Health Code',
        'كود وزارة الصحة',
        'رمز وزارة الصحة',
      ]);
      if (nameIndex < 0) throw StateError('MATERIAL_NAME_COLUMN_NOT_FOUND');

      String valueAt(List<xls.Data?> row, int index) {
        if (index < 0 || index >= row.length) return '';
        return row[index]?.value.toString().trim() ?? '';
      }

      final List<Map<String, String>> rows = <Map<String, String>>[];
      for (int index = 1; index < sheet.rows.length; index++) {
        final List<xls.Data?> row = sheet.rows[index];
        final String name = valueAt(row, nameIndex);
        if (name.isEmpty) continue;
        rows.add(<String, String>{
          'name': name,
          'abbott_list_no': valueAt(row, abbottIndex),
          'moh_code': valueAt(row, mohIndex),
        });
      }
      if (rows.isEmpty) throw StateError('NO_VALID_MATERIAL_ROWS');
      final int imported = await widget.repository.importProductCatalog(
        actorId: widget.actorId,
        sourceFile: selectedFile.name,
        rows: rows,
      );
      final List<ProductCatalogRecord> entries =
          await widget.repository.productCatalog();
      if (!mounted) return;
      setState(() {
        catalog = entries;
        selectedMaterial = null;
        abbottListNo.clear();
        mohCode.clear();
      });
      final InventoryText text = InventoryText(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${text.importedRows}: $imported'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final ProductCatalogRecord? selected = selectedMaterial;
    if (selected == null) return;
    setState(() => saving = true);
    try {
      final InventoryIntakeResult result = await widget.repository
          .createInventoryIntake(
            actorId: widget.actorId,
            internalNumber: internalNumber.text,
            rawBarcode: widget.rawBarcode,
            barcodeFormat: widget.barcodeFormat,
            gtin: widget.gtin,
            lotNumber: widget.lotNumber,
            catalogNumber: widget.catalogNumber,
            receivedAt: DateTime.now(),
            manufacturerExpiry: widget.manufacturerExpiry,
            cartonCode: cartonCode.text,
            unitCount: int.parse(unitCount.text),
            catalogEntry: selected,
            materialType: _selected(materialType, otherType),
            department: _selected(department, otherDepartment),
            deviceName: _selected(device, otherDevice),
            storageLocation: _selected(storage, otherStorage),
            measureUnit: _selected(measureUnit, otherMeasureUnit),
            stabilityEnabled: stabilityEnabled,
            stabilityValue:
                stabilityEnabled ? int.parse(stabilityValue.text) : 0,
            stabilityPeriod: stabilityPeriod,
          );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
    );
  }

  String? _required(String? value) {
    return value?.trim().isEmpty ?? true
        ? InventoryText(context).required
        : null;
  }

  Widget _readOnly(String label, String value, {int maxLines = 1}) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
    TextEditingController? otherController,
  }) {
    return Column(
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: ValueKey<String>('$label-$value'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items:
              values
                  .map(
                    (String item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item == otherValue
                            ? InventoryText(context).other
                            : item,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (String? selected) {
            if (selected != null) onChanged(selected);
          },
          validator: _required,
        ),
        if (value == otherValue && otherController != null) ...<Widget>[
          const SizedBox(height: 10),
          TextFormField(
            controller: otherController,
            decoration: InputDecoration(
              labelText: '${InventoryText(context).other} - $label',
            ),
            validator: _required,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(text.intakeTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(text.intakeTitle)),
      body: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              text.automaticData,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _readOnly(text.internalNumber, internalNumber.text),
            const SizedBox(height: 10),
            _readOnly(text.rawBarcode, widget.rawBarcode, maxLines: 3),
            const SizedBox(height: 10),
            _readOnly(text.gtin, widget.gtin),
            const SizedBox(height: 10),
            _readOnly(text.lot, widget.lotNumber),
            const SizedBox(height: 10),
            _readOnly(text.catalog, widget.catalogNumber),
            const SizedBox(height: 10),
            _readOnly(
              text.receivedAt,
              _date(DateTime.now(), includeTime: true),
            ),
            const SizedBox(height: 10),
            _readOnly(
              text.manufacturerExpiry,
              _date(widget.manufacturerExpiry),
            ),
            const SizedBox(height: 20),
            Text(
              text.requiredData,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (catalog.isEmpty) ...<Widget>[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(text.catalogEmpty),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: saving ? null : _importCatalog,
              icon: const Icon(Icons.upload_file),
              label: Text(text.importCatalog),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProductCatalogRecord>(
              key: ValueKey<int?>(selectedMaterial?.id),
              initialValue: selectedMaterial,
              decoration: InputDecoration(labelText: text.materialName),
              items:
                  catalog
                      .map(
                        (ProductCatalogRecord item) =>
                            DropdownMenuItem<ProductCatalogRecord>(
                              value: item,
                              child: Text(item.name),
                            ),
                      )
                      .toList(),
              onChanged: (ProductCatalogRecord? value) {
                _selectMaterial(value);
              },
              validator:
                  (ProductCatalogRecord? value) =>
                      value == null ? text.required : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: abbottListNo,
              readOnly: true,
              decoration: InputDecoration(
                labelText: text.abbottListNo,
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: mohCode,
              readOnly: true,
              decoration: InputDecoration(
                labelText: text.mohCode,
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: text.type,
              value: materialType,
              values: const <String>[
                'Reagent',
                'Control',
                'Calibrator',
                'Consumable',
                otherValue,
              ],
              onChanged: (String value) => setState(() => materialType = value),
              otherController: otherType,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: stabilityEnabled,
              title: Text(text.stabilityOption),
              onChanged:
                  (bool value) => setState(() => stabilityEnabled = value),
            ),
            if (stabilityEnabled) ...<Widget>[
              TextFormField(
                controller: stabilityValue,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: text.stabilityDuration),
                validator: (String? value) {
                  final int? number = int.tryParse(value ?? '');
                  return number == null || number <= 0
                      ? text.invalidNumber
                      : null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: stabilityPeriod,
                decoration: InputDecoration(labelText: text.stabilityPeriod),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'hour', child: Text(text.hour)),
                  DropdownMenuItem(value: 'day', child: Text(text.day)),
                  DropdownMenuItem(value: 'week', child: Text(text.week)),
                  DropdownMenuItem(value: 'month', child: Text(text.month)),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => stabilityPeriod = value);
                  }
                },
              ),
            ],
            const SizedBox(height: 10),
            _dropdown(
              label: text.department,
              value: department,
              values: const <String>['Chemistry', otherValue],
              onChanged: (String value) => setState(() => department = value),
              otherController: otherDepartment,
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: text.device,
              value: device,
              values: const <String>['Alinity', otherValue],
              onChanged: (String value) => setState(() => device = value),
              otherController: otherDevice,
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: text.storage,
              value: storage,
              values: const <String>[
                'Fridge #1',
                'Fridge #2',
                'Fridge #3',
                'Fridge #4',
                otherValue,
              ],
              onChanged: (String value) => setState(() => storage = value),
              otherController: otherStorage,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: cartonCode,
              readOnly: true,
              decoration: InputDecoration(
                labelText: text.cartonCode,
                filled: true,
              ),
              validator: _required,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: unitCount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: text.unitsPerCarton),
              validator: (String? value) {
                final int? number = int.tryParse(value ?? '');
                return number == null || number < 1 || number > 1000
                    ? text.invalidNumber
                    : null;
              },
            ),
            const SizedBox(height: 10),
            _dropdown(
              label: text.measureUnit,
              value: measureUnit,
              values: const <String>[
                'mL',
                'Tests',
                'Vials',
                'Bottles',
                'Cartridges',
                'Packs',
                otherValue,
              ],
              onChanged: (String value) => setState(() => measureUnit = value),
              otherController: otherMeasureUnit,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saving || catalog.isEmpty ? null : _save,
              icon:
                  saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(text.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
