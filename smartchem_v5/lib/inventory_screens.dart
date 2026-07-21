import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'inventory_models.dart';
import 'inventory_repository.dart';
import 'inventory_text.dart';
import 'label_service.dart';

class ProductInventoryScreen extends StatefulWidget {
  const ProductInventoryScreen({
    super.key,
    required this.repository,
    required this.actorId,
    required this.canManage,
  });

  final InventoryRepository repository;
  final int actorId;
  final bool canManage;

  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  int revision = 0;

  void refresh() => setState(() => revision++);

  Future<void> editProduct([ProductRecord? product]) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => _ProductDialog(
            repository: widget.repository,
            actorId: widget.actorId,
            product: product,
          ),
    );
    if (saved == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.hierarchy)),
      floatingActionButton:
          widget.canManage
              ? FloatingActionButton.extended(
                onPressed: editProduct,
                icon: const Icon(Icons.add),
                label: Text(text.addProduct),
              )
              : null,
      body: FutureBuilder<List<ProductRecord>>(
        key: ValueKey<int>(revision),
        future: widget.repository.products(),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<ProductRecord>> snapshot,
        ) {
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<ProductRecord> products = snapshot.data!;
          if (products.isEmpty) {
            return Center(child: Text(text.noData));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final ProductRecord product = products[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.science)),
                  title: Text(product.name),
                  subtitle: Text(
                    '${product.sku} • ${text.lots}: ${product.lotCount} • '
                    '${text.cartons}: ${product.cartonCount} • '
                    '${text.units}: ${product.unitCount}\n'
                    '${text.afterOpenDays}: ${product.afterOpenDays}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.canManage)
                        IconButton(
                          onPressed: () => editProduct(product),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => ProductDetailsScreen(
                              repository: widget.repository,
                              actorId: widget.actorId,
                              canManage: widget.canManage,
                              productId: product.id,
                            ),
                      ),
                    );
                    refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    required this.repository,
    required this.actorId,
    this.product,
  });

  final InventoryRepository repository;
  final int actorId;
  final ProductRecord? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController sku;
  late final TextEditingController name;
  late final TextEditingController type;
  late final TextEditingController gtin;
  late final TextEditingController catalog;
  late final TextEditingController manufacturer;
  late final TextEditingController department;
  late final TextEditingController storage;
  late final TextEditingController measureUnit;
  late final TextEditingController afterOpenDays;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final ProductRecord? product = widget.product;
    sku = TextEditingController(text: product?.sku ?? '');
    name = TextEditingController(text: product?.name ?? '');
    type = TextEditingController(text: product?.type ?? '');
    gtin = TextEditingController(text: product?.gtin ?? '');
    catalog = TextEditingController(text: product?.catalogNumber ?? '');
    manufacturer = TextEditingController(text: product?.manufacturer ?? '');
    department = TextEditingController(text: product?.department ?? '');
    storage = TextEditingController(text: product?.storageLocation ?? '');
    measureUnit = TextEditingController(text: product?.defaultUnit ?? 'mL');
    afterOpenDays = TextEditingController(
      text: (product?.afterOpenDays ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      sku,
      name,
      type,
      gtin,
      catalog,
      manufacturer,
      department,
      storage,
      measureUnit,
      afterOpenDays,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await widget.repository.saveProduct(
        actorId: widget.actorId,
        productId: widget.product?.id,
        values: <String, Object?>{
          'sku': sku.text.trim(),
          'name': name.text.trim(),
          'type': type.text.trim(),
          'gtin': gtin.text.trim(),
          'catalog_number': catalog.text.trim(),
          'manufacturer': manufacturer.text.trim(),
          'department': department.text.trim(),
          'storage_location': storage.text.trim(),
          'default_unit': measureUnit.text.trim(),
          'after_open_days': int.parse(afterOpenDays.text),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    return AlertDialog(
      title: Text(widget.product == null ? text.addProduct : text.editProduct),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  <Widget>[
                        _field(sku, text.sku, required: true),
                        _field(name, text.name, required: true),
                        _field(type, text.type),
                        _field(gtin, text.gtin),
                        _field(catalog, text.catalog),
                        _field(manufacturer, text.manufacturer),
                        _field(department, text.department),
                        _field(storage, text.storage),
                        _field(measureUnit, text.measureUnit, required: true),
                        TextFormField(
                          controller: afterOpenDays,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: text.afterOpenDays,
                          ),
                          validator: (String? value) {
                            final int? days = int.tryParse(value ?? '');
                            return days == null || days < 0
                                ? text.invalidNumber
                                : null;
                          },
                        ),
                      ]
                      .expand(
                        (Widget child) => <Widget>[
                          child,
                          const SizedBox(height: 10),
                        ],
                      )
                      .toList(),
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: Text(text.cancel),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child:
              busy
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(text.save),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    final InventoryText text = InventoryText(context);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator:
          required
              ? (String? value) =>
                  (value?.trim().isEmpty ?? true) ? text.required : null
              : null,
    );
  }
}

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.repository,
    required this.actorId,
    required this.canManage,
    required this.productId,
  });

  final InventoryRepository repository;
  final int actorId;
  final bool canManage;
  final int productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int revision = 0;

  Future<void> addLot() async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder:
          (_) => _LotDialog(
            repository: widget.repository,
            actorId: widget.actorId,
            productId: widget.productId,
          ),
    );
    if (saved == true) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    return FutureBuilder<ProductRecord?>(
      key: ValueKey<int>(revision),
      future: widget.repository.productById(widget.productId),
      builder: (BuildContext context, AsyncSnapshot<ProductRecord?> snapshot) {
        final ProductRecord? product = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(product?.name ?? text.product)),
          floatingActionButton:
              widget.canManage && product != null
                  ? FloatingActionButton.extended(
                    onPressed: addLot,
                    icon: const Icon(Icons.add),
                    label: Text(text.addLot),
                  )
                  : null,
          body:
              product == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<LotRecord>>(
                    future: widget.repository.lots(product.id),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<List<LotRecord>> lotSnapshot,
                    ) {
                      if (lotSnapshot.hasError) {
                        return _ErrorView(error: lotSnapshot.error);
                      }
                      if (!lotSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        children: <Widget>[
                          _InfoCard(
                            rows: <MapEntry<String, String>>[
                              MapEntry(text.sku, product.sku),
                              MapEntry(text.gtin, product.gtin),
                              MapEntry(text.catalog, product.catalogNumber),
                              MapEntry(text.manufacturer, product.manufacturer),
                              MapEntry(
                                text.afterOpenDays,
                                product.afterOpenDays.toString(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            text.lots,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (lotSnapshot.data!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(child: Text(text.noData)),
                            ),
                          for (final LotRecord lot in lotSnapshot.data!)
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      lot.isExpired ? Colors.red : null,
                                  child: const Icon(Icons.layers),
                                ),
                                title: Text(lot.lotNumber),
                                subtitle: Text(
                                  '${text.expiry}: ${_date(lot.manufacturerExpiry)}\n'
                                  '${text.cartons}: ${lot.cartonCount} • '
                                  '${text.units}: ${lot.unitCount}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => LotDetailsScreen(
                                            repository: widget.repository,
                                            actorId: widget.actorId,
                                            canManage: widget.canManage,
                                            product: product,
                                            lotId: lot.id,
                                          ),
                                    ),
                                  );
                                  setState(() => revision++);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
        );
      },
    );
  }
}

class _LotDialog extends StatefulWidget {
  const _LotDialog({
    required this.repository,
    required this.actorId,
    required this.productId,
  });

  final InventoryRepository repository;
  final int actorId;
  final int productId;

  @override
  State<_LotDialog> createState() => _LotDialogState();
}

class _LotDialogState extends State<_LotDialog> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController lot = TextEditingController();
  final TextEditingController expiry = TextEditingController();
  final TextEditingController received = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    lot.dispose();
    expiry.dispose();
    received.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await widget.repository.addLot(
        actorId: widget.actorId,
        productId: widget.productId,
        lotNumber: lot.text,
        manufacturerExpiry: DateTime.tryParse(expiry.text.trim()),
        receivedAt: DateTime.tryParse(received.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    return AlertDialog(
      title: Text(text.addLot),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: lot,
              decoration: InputDecoration(labelText: text.lot),
              validator:
                  (String? value) =>
                      (value?.trim().isEmpty ?? true) ? text.required : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: expiry,
              decoration: InputDecoration(
                labelText: '${text.expiry} YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: received,
              decoration: InputDecoration(
                labelText: '${text.received} YYYY-MM-DD',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: Text(text.cancel),
        ),
        FilledButton(onPressed: busy ? null : save, child: Text(text.save)),
      ],
    );
  }
}

class LotDetailsScreen extends StatefulWidget {
  const LotDetailsScreen({
    super.key,
    required this.repository,
    required this.actorId,
    required this.canManage,
    required this.product,
    required this.lotId,
  });

  final InventoryRepository repository;
  final int actorId;
  final bool canManage;
  final ProductRecord product;
  final int lotId;

  @override
  State<LotDetailsScreen> createState() => _LotDetailsScreenState();
}

class _LotDetailsScreenState extends State<LotDetailsScreen> {
  int revision = 0;

  Future<void> addCarton(LotRecord lot) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder:
          (_) => _CartonDialog(
            repository: widget.repository,
            actorId: widget.actorId,
            lotId: lot.id,
            defaultUnit: widget.product.defaultUnit,
          ),
    );
    if (saved == true) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    return FutureBuilder<LotRecord?>(
      key: ValueKey<int>(revision),
      future: widget.repository.lotById(widget.lotId),
      builder: (BuildContext context, AsyncSnapshot<LotRecord?> snapshot) {
        final LotRecord? lot = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(lot?.lotNumber ?? text.lot)),
          floatingActionButton:
              widget.canManage && lot != null
                  ? FloatingActionButton.extended(
                    onPressed: () => addCarton(lot),
                    icon: const Icon(Icons.add_box_outlined),
                    label: Text(text.addCarton),
                  )
                  : null,
          body:
              lot == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<CartonRecord>>(
                    future: widget.repository.cartons(lot.id),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<List<CartonRecord>> cartonSnapshot,
                    ) {
                      if (cartonSnapshot.hasError) {
                        return _ErrorView(error: cartonSnapshot.error);
                      }
                      if (!cartonSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final List<CartonRecord> cartons = cartonSnapshot.data!;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        children: <Widget>[
                          _InfoCard(
                            rows: <MapEntry<String, String>>[
                              MapEntry(text.product, widget.product.name),
                              MapEntry(text.lot, lot.lotNumber),
                              MapEntry(
                                text.expiry,
                                _date(lot.manufacturerExpiry),
                              ),
                              MapEntry(text.received, _date(lot.receivedAt)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            text.cartons,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (cartons.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(child: Text(text.noData)),
                            ),
                          for (final CartonRecord carton in cartons)
                            Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.inventory_2_outlined),
                                ),
                                title: Text(carton.cartonCode),
                                subtitle: Text(
                                  '${text.units}: ${carton.actualUnitCount} • '
                                  '${text.opened}: ${carton.openUnitCount}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => CartonDetailsScreen(
                                            repository: widget.repository,
                                            actorId: widget.actorId,
                                            canManage: widget.canManage,
                                            product: widget.product,
                                            lot: lot,
                                            cartonId: carton.id,
                                          ),
                                    ),
                                  );
                                  setState(() => revision++);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
        );
      },
    );
  }
}

class _CartonDialog extends StatefulWidget {
  const _CartonDialog({
    required this.repository,
    required this.actorId,
    required this.lotId,
    required this.defaultUnit,
  });

  final InventoryRepository repository;
  final int actorId;
  final int lotId;
  final String defaultUnit;

  @override
  State<_CartonDialog> createState() => _CartonDialogState();
}

class _CartonDialogState extends State<_CartonDialog> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController code = TextEditingController();
  final TextEditingController count = TextEditingController(text: '1');
  final TextEditingController quantity = TextEditingController(text: '1');
  late final TextEditingController measureUnit = TextEditingController(
    text: widget.defaultUnit,
  );
  bool busy = false;

  @override
  void dispose() {
    code.dispose();
    count.dispose();
    quantity.dispose();
    measureUnit.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await widget.repository.addCartonWithUnits(
        actorId: widget.actorId,
        lotId: widget.lotId,
        cartonCode: code.text,
        unitCount: int.parse(count.text),
        quantityPerUnit: double.parse(quantity.text),
        measureUnit: measureUnit.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    String? positiveNumber(String? value) {
      final double? number = double.tryParse(value ?? '');
      return number == null || number <= 0 ? text.invalidNumber : null;
    }

    return AlertDialog(
      title: Text(text.addCarton),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: code,
              decoration: InputDecoration(labelText: text.cartonCode),
              validator:
                  (String? value) =>
                      (value?.trim().isEmpty ?? true) ? text.required : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: count,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: text.unitCount),
              validator: (String? value) {
                final int? number = int.tryParse(value ?? '');
                return number == null || number < 1 || number > 1000
                    ? text.invalidNumber
                    : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: text.quantityPerUnit),
              validator: positiveNumber,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: measureUnit,
              decoration: InputDecoration(labelText: text.measureUnit),
              validator:
                  (String? value) =>
                      (value?.trim().isEmpty ?? true) ? text.required : null,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: Text(text.cancel),
        ),
        FilledButton(onPressed: busy ? null : save, child: Text(text.save)),
      ],
    );
  }
}

class CartonDetailsScreen extends StatefulWidget {
  const CartonDetailsScreen({
    super.key,
    required this.repository,
    required this.actorId,
    required this.canManage,
    required this.product,
    required this.lot,
    required this.cartonId,
  });

  final InventoryRepository repository;
  final int actorId;
  final bool canManage;
  final ProductRecord product;
  final LotRecord lot;
  final int cartonId;

  @override
  State<CartonDetailsScreen> createState() => _CartonDetailsScreenState();
}

class _CartonDetailsScreenState extends State<CartonDetailsScreen> {
  int revision = 0;
  bool printing = false;

  Future<void> printCarton(CartonRecord carton) async {
    setState(() => printing = true);
    try {
      final Uint8List bytes = await InventoryLabelService.cartonLabel(
        product: widget.product,
        lot: widget.lot,
        carton: carton,
      );
      final bool printed = await Printing.layoutPdf(
        name: 'SmartChem-Carton-${carton.cartonCode}',
        onLayout: (_) async => bytes,
      );
      if (printed) {
        await widget.repository.recordLabelPrint(
          actorId: widget.actorId,
          entityType: 'carton',
          entityId: carton.id,
          copies: 1,
        );
        if (mounted) _showSuccess(context, InventoryText(context).labelQueued);
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  Future<void> printUnits(List<UnitRecord> units) async {
    if (units.isEmpty) return;
    setState(() => printing = true);
    try {
      final Uint8List bytes = await InventoryLabelService.unitLabels(
        product: widget.product,
        units: units,
      );
      final bool printed = await Printing.layoutPdf(
        name: 'SmartChem-Units-${units.first.cartonCode}',
        onLayout: (_) async => bytes,
      );
      if (printed) {
        for (final UnitRecord unit in units) {
          await widget.repository.recordLabelPrint(
            actorId: widget.actorId,
            entityType: 'unit',
            entityId: unit.id,
            copies: 1,
          );
        }
        if (mounted) _showSuccess(context, InventoryText(context).labelQueued);
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    return FutureBuilder<CartonRecord?>(
      key: ValueKey<int>(revision),
      future: widget.repository.cartonById(widget.cartonId),
      builder: (BuildContext context, AsyncSnapshot<CartonRecord?> snapshot) {
        final CartonRecord? carton = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(carton?.cartonCode ?? text.carton)),
          body:
              carton == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<UnitRecord>>(
                    future: widget.repository.units(carton.id),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<List<UnitRecord>> unitSnapshot,
                    ) {
                      if (unitSnapshot.hasError) {
                        return _ErrorView(error: unitSnapshot.error);
                      }
                      if (!unitSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final List<UnitRecord> units = unitSnapshot.data!;
                      return ListView(
                        padding: const EdgeInsets.all(12),
                        children: <Widget>[
                          _InfoCard(
                            rows: <MapEntry<String, String>>[
                              MapEntry(text.product, widget.product.name),
                              MapEntry(text.lot, widget.lot.lotNumber),
                              MapEntry(text.cartonCode, carton.cartonCode),
                              MapEntry(text.unitCount, units.length.toString()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              FilledButton.icon(
                                onPressed:
                                    printing ? null : () => printCarton(carton),
                                icon: const Icon(Icons.print),
                                label: Text(text.printCarton),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    printing ? null : () => printUnits(units),
                                icon: const Icon(Icons.print_outlined),
                                label: Text(text.printUnits),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            text.units,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          for (final UnitRecord unit in units)
                            Card(
                              child: ListTile(
                                leading: Icon(
                                  unit.isEmpty
                                      ? Icons.remove_circle
                                      : unit.isOpened
                                      ? Icons.lock_open
                                      : Icons.lock_outline,
                                  color:
                                      unit.isExpired
                                          ? Colors.red
                                          : unit.isOpened
                                          ? Colors.orange
                                          : Colors.green,
                                ),
                                title: Text(unit.unitCode),
                                subtitle: Text(
                                  '${text.remaining}: ${unit.remainingQuantity} '
                                  '${unit.measureUnit} • '
                                  '${text.effectiveExpiry}: '
                                  '${_date(unit.effectiveExpiry)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => UnitDetailsScreen(
                                            repository: widget.repository,
                                            actorId: widget.actorId,
                                            canManage: widget.canManage,
                                            product: widget.product,
                                            unitId: unit.id,
                                          ),
                                    ),
                                  );
                                  setState(() => revision++);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
        );
      },
    );
  }
}

class UnitDetailsScreen extends StatefulWidget {
  const UnitDetailsScreen({
    super.key,
    required this.repository,
    required this.actorId,
    required this.canManage,
    required this.product,
    required this.unitId,
  });

  final InventoryRepository repository;
  final int actorId;
  final bool canManage;
  final ProductRecord product;
  final int unitId;

  @override
  State<UnitDetailsScreen> createState() => _UnitDetailsScreenState();
}

class _UnitDetailsScreenState extends State<UnitDetailsScreen> {
  int revision = 0;
  bool busy = false;

  Future<void> openUnit() async {
    setState(() => busy = true);
    try {
      await widget.repository.openUnit(
        actorId: widget.actorId,
        unitId: widget.unitId,
      );
      if (mounted) setState(() => revision++);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> useUnit() async {
    final InventoryText text = InventoryText(context);
    final TextEditingController quantity = TextEditingController();
    final TextEditingController note = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            title: Text(text.recordUsage),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: text.usageQuantity),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: text.reason),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(text.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(text.save),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      quantity.dispose();
      note.dispose();
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.recordUsage(
        actorId: widget.actorId,
        unitId: widget.unitId,
        quantity: double.parse(quantity.text),
        note: note.text,
      );
      if (mounted) setState(() => revision++);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      quantity.dispose();
      note.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> printUnit(UnitRecord unit) async {
    setState(() => busy = true);
    try {
      final Uint8List bytes = await InventoryLabelService.unitLabels(
        product: widget.product,
        units: <UnitRecord>[unit],
      );
      final bool printed = await Printing.layoutPdf(
        name: 'SmartChem-Unit-${unit.unitCode}',
        onLayout: (_) async => bytes,
      );
      if (printed) {
        await widget.repository.recordLabelPrint(
          actorId: widget.actorId,
          entityType: 'unit',
          entityId: unit.id,
          copies: 1,
        );
        if (mounted) _showSuccess(context, InventoryText(context).labelQueued);
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InventoryText text = InventoryText(context);
    return FutureBuilder<UnitRecord?>(
      key: ValueKey<int>(revision),
      future: widget.repository.unitById(widget.unitId),
      builder: (BuildContext context, AsyncSnapshot<UnitRecord?> snapshot) {
        final UnitRecord? unit = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(unit?.unitCode ?? text.unit)),
          body:
              unit == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      _InfoCard(
                        rows: <MapEntry<String, String>>[
                          MapEntry(text.product, unit.productName),
                          MapEntry(text.lot, unit.lotNumber),
                          MapEntry(text.cartonCode, unit.cartonCode),
                          MapEntry(text.unit, unit.unitCode),
                          MapEntry(
                            text.remaining,
                            '${unit.remainingQuantity} ${unit.measureUnit}',
                          ),
                          MapEntry(text.openedAt, _date(unit.openedAt)),
                          MapEntry(
                            text.afterOpenExpiry,
                            _date(unit.afterOpenExpiry),
                          ),
                          MapEntry(
                            text.effectiveExpiry,
                            _date(unit.effectiveExpiry),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (widget.canManage && !unit.isOpened && !unit.isEmpty)
                        FilledButton.icon(
                          onPressed: busy ? null : openUnit,
                          icon: const Icon(Icons.lock_open),
                          label: Text(text.openUnit),
                        ),
                      if (!unit.isEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: busy ? null : useUnit,
                          icon: const Icon(Icons.science_outlined),
                          label: Text(text.recordUsage),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => printUnit(unit),
                        icon: const Icon(Icons.print),
                        label: Text(text.printUnit),
                      ),
                    ],
                  ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children:
              rows
                  .map(
                    (MapEntry<String, String> row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: Text(
                              row.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(row.value.isEmpty ? '-' : row.value),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(error.toString(), textAlign: TextAlign.center),
      ),
    );
  }
}

String _date(DateTime? value) {
  if (value == null) return '-';
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
  );
}

void _showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.green),
  );
}
