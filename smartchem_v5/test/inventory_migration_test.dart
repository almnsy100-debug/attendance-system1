import 'package:excel/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:production/inventory_export_service.dart';
import 'package:production/inventory_models.dart';
import 'package:production/inventory_repository.dart';
import 'package:production/label_service.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database database;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('PRAGMA foreign_keys = ON');
    await _createLegacySchema(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'v2 migration preserves legacy inventory and links all hierarchy rows',
    () async {
      await _insertLegacyMaterial(database);

      await InventoryRepository.upgrade(
        database,
        2,
        InventoryRepository.schemaVersion,
      );

      expect(
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM materials'),
        ),
        1,
      );
      final Map<String, Object?> legacy =
          (await database.query('materials')).single;
      expect(legacy['name'], 'Control reagent');
      expect(legacy['original_quantity'], 50.0);
      expect(legacy['used_quantity'], 5.0);

      for (final String table in <String>[
        'products',
        'lots',
        'cartons',
        'units',
      ]) {
        expect(
          Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM $table'),
          ),
          1,
          reason: table,
        );
      }

      final Map<String, Object?> product =
          (await database.query('products')).single;
      expect(product['after_open_days'], 30);
      expect(product['stability_enabled'], 1);
      expect(product['stability_value'], 30);
      expect(product['stability_period'], 'day');
      expect(product['gtin'], '00380740150005');

      final Map<String, Object?> unit = (await database.query('units')).single;
      expect(unit['legacy_material_id'], 42);
      expect(unit['original_quantity'], 50.0);
      expect(unit['used_quantity'], 5.0);
      expect(unit['opened_at'], '2026-01-01T00:00:00.000');
      expect(unit['after_open_expiry'], '2026-01-31T00:00:00.000');
      expect(unit['sequence_number'], 1);

      expect(
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM product_catalog'),
        ),
        49,
      );
      final Map<String, Object?> bundled =
          (await database.query(
            'product_catalog',
            where: 'name = ?',
            whereArgs: <Object?>['ALINITY C ALK PHOS 4000T'],
          )).single;
      expect(bundled['abbott_list_no'], '8P2020');
      expect(bundled['moh_code'], '060R0072232');

      final Map<String, Object?> usage =
          (await database.query('usage_records')).single;
      expect(usage['unit_id'], unit['id']);

      await InventoryRepository.upgrade(
        database,
        2,
        InventoryRepository.schemaVersion,
      );
      expect(
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM units'),
        ),
        1,
        reason: 'migration must be idempotent',
      );
    },
  );

  test('v5 hierarchy upgrades in place without deleting inventory', () async {
    await _createV5HierarchySchema(database);
    await database.insert('products', <String, Object?>{
      'id': 100,
      'sku': 'V5-PRODUCT',
      'name': 'Preserved v5 product',
      'default_unit': 'Tests',
      'after_open_days': 7,
      'created_by': 1,
      'created_at': '2026-01-01T00:00:00.000',
    });
    await database.insert('lots', <String, Object?>{
      'id': 200,
      'product_id': 100,
      'lot_number': 'V5-LOT',
      'created_by': 1,
      'created_at': '2026-01-01T00:00:00.000',
    });
    await database.insert('cartons', <String, Object?>{
      'id': 300,
      'lot_id': 200,
      'carton_code': 'V5-CARTON',
      'expected_unit_count': 1,
      'created_by': 1,
      'created_at': '2026-01-01T00:00:00.000',
    });
    await database.insert('units', <String, Object?>{
      'id': 400,
      'carton_id': 300,
      'unit_code': 'V5-CARTON-U001',
      'original_quantity': 25,
      'used_quantity': 4,
      'measure_unit': 'Tests',
      'created_by': 1,
      'created_at': '2026-01-01T00:00:00.000',
    });

    await InventoryRepository.upgrade(
      database,
      5,
      InventoryRepository.schemaVersion,
    );

    final Map<String, Object?> product =
        (await database.query('products', where: 'id = 100')).single;
    expect(product['name'], 'Preserved v5 product');
    expect(product['stability_enabled'], 1);
    expect(product['stability_value'], 7);
    expect(product['stability_period'], 'day');

    final Map<String, Object?> unit =
        (await database.query('units', where: 'id = 400')).single;
    expect(unit['used_quantity'], 4.0);
    expect(unit['sequence_number'], 1);
    expect(
      (await database.query(
        'cartons',
        where: 'id = 300',
      )).single['carton_code'],
      'V5-CARTON',
    );
  });

  test(
    'opening a unit calculates after-open expiry from the product policy',
    () async {
      final DateTime now = DateTime.now();
      final DateTime openedDate = DateTime(now.year, now.month, now.day);
      final DateTime lotExpiry = openedDate.add(const Duration(days: 365));
      await InventoryRepository.upgrade(
        database,
        2,
        InventoryRepository.schemaVersion,
      );
      final InventoryRepository repository = InventoryRepository(database);
      final int productId = await repository.saveProduct(
        actorId: 1,
        values: <String, Object?>{
          'sku': 'P-001',
          'name': 'Calibrator',
          'type': 'Reagent',
          'gtin': '',
          'catalog_number': 'CAL-1',
          'manufacturer': 'SmartChem',
          'department': 'Chemistry',
          'storage_location': 'Fridge 1',
          'default_unit': 'mL',
          'after_open_days': 14,
        },
      );
      final int lotId = await repository.addLot(
        actorId: 1,
        productId: productId,
        lotNumber: 'LOT-2026-A',
        manufacturerExpiry: lotExpiry,
      );
      final int cartonId = await repository.addCartonWithUnits(
        actorId: 1,
        lotId: lotId,
        cartonCode: 'CTN-0001',
        unitCount: 2,
        quantityPerUnit: 25,
        measureUnit: 'mL',
      );
      final units = await repository.units(cartonId);

      await repository.openUnit(
        actorId: 1,
        unitId: units.first.id,
        openedAt: openedDate,
      );

      final opened = await repository.unitById(units.first.id);
      expect(opened, isNotNull);
      expect(opened!.openedAt, openedDate);
      expect(opened.afterOpenExpiry, openedDate.add(const Duration(days: 14)));
      expect(opened.effectiveExpiry, openedDate.add(const Duration(days: 14)));

      await repository.recordUsage(
        actorId: 1,
        unitId: opened.id,
        quantity: 5,
        note: 'QC run',
      );
      final used = await repository.unitById(opened.id);
      expect(used!.remainingQuantity, 20);
      expect(used.status, 'opened');
      expect(
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM unit_usage_records'),
        ),
        1,
      );
    },
  );

  test('precise stability supports hours, weeks and calendar months', () {
    final DateTime opened = DateTime(2026, 1, 31, 10, 15);
    expect(
      calculateStabilityExpiry(opened, 5, 'hour'),
      DateTime(2026, 1, 31, 15, 15),
    );
    expect(
      calculateStabilityExpiry(opened, 2, 'week'),
      DateTime(2026, 2, 14, 10, 15),
    );
    expect(
      calculateStabilityExpiry(opened, 1, 'month'),
      DateTime(2026, 2, 28, 10, 15),
    );
  });

  test(
    'scanned intake creates carton and sequential unit label codes',
    () async {
      await InventoryRepository.upgrade(
        database,
        2,
        InventoryRepository.schemaVersion,
      );
      final InventoryRepository repository = InventoryRepository(database);
      await repository.importProductCatalog(
        actorId: 1,
        sourceFile: 'materials.xlsx',
        rows: <Map<String, String>>[
          <String, String>{
            'name': 'Alinity Reagent',
            'abbott_list_no': '09P95',
            'moh_code': 'MOH-100',
          },
        ],
      );
      final ProductCatalogRecord catalog = (await repository.productCatalog())
          .singleWhere(
            (ProductCatalogRecord item) => item.name == 'Alinity Reagent',
          );
      final InventoryIntakeResult result = await repository
          .createInventoryIntake(
            actorId: 1,
            internalNumber: 'SC-260101-0001',
            rawBarcode: '(01)00380740150005(10)LOT-A',
            barcodeFormat: 'dataMatrix',
            gtin: '00380740150005',
            lotNumber: 'LOT-A',
            catalogNumber: '09P9510',
            receivedAt: DateTime(2026, 1, 1),
            manufacturerExpiry: DateTime(2027, 1, 1),
            cartonCode: 'ALT2-84441UD00',
            unitCount: 4,
            quantityPerUnit: 5,
            catalogEntry: catalog,
            materialType: 'Reagent',
            department: 'Chemistry',
            deviceName: 'Alinity',
            storageLocation: 'Fridge #1',
            measureUnit: 'Tests',
            stabilityEnabled: true,
            stabilityValue: 5,
            stabilityPeriod: 'hour',
          );

      final ProductRecord product =
          (await repository.productById(result.productId))!;
      expect(product.abbottListNo, '09P95');
      expect(product.mohCode, 'MOH-100');
      expect(product.deviceName, 'Alinity');
      expect(product.stabilityEnabled, isTrue);
      expect(product.stabilityValue, 5);
      expect(product.stabilityPeriod, 'hour');

      final List<UnitRecord> units = await repository.units(result.cartonId);
      expect(units.map((UnitRecord unit) => unit.unitCode), <String>[
        'ALT2-84441UD00-001',
        'ALT2-84441UD00-002',
        'ALT2-84441UD00-003',
        'ALT2-84441UD00-004',
      ]);
      expect(units.map((UnitRecord unit) => unit.sequenceNumber), <int>[
        1,
        2,
        3,
        4,
      ]);
      expect(
        units.every((UnitRecord unit) => unit.originalQuantity == 5),
        isTrue,
      );
      final List<UnitRecord> allUnits = await repository.allUnits();
      expect(allUnits, hasLength(4));
      expect(allUnits.first.productSku, 'SC-260101-0001');
      expect(allUnits.first.gtin, '00380740150005');
      expect(allUnits.first.catalogNumber, '09P9510');
      expect(allUnits.first.abbottListNo, '09P95');
      expect(allUnits.first.mohCode, 'MOH-100');
      expect(allUnits.first.receivedAt, DateTime(2026, 1, 1));
      expect(allUnits.first.storageLocation, 'Fridge #1');

      final xls.Excel export = xls.Excel.decodeBytes(
        InventoryExportService.excelBytes(units),
      );
      expect(export.tables['Inventory']?.rows, hasLength(5));
      final List<int> pdf = await InventoryExportService.pdfBytes(units);
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      final LotRecord lot = (await repository.lotById(result.lotId))!;
      final CartonRecord carton =
          (await repository.cartonById(result.cartonId))!;
      final List<int> cartonLabel = await InventoryLabelService.cartonLabel(
        product: product,
        lot: lot,
        carton: carton,
        units: units,
      );
      expect(String.fromCharCodes(cartonLabel.take(4)), '%PDF');
      final List<int> unitLabels = await InventoryLabelService.unitLabels(
        product: product,
        units: units,
      );
      expect(String.fromCharCodes(unitLabels.take(4)), '%PDF');
      expect(
        (await repository.findCarton('(01)00380740150005(10)LOT-A'))?.id,
        result.cartonId,
      );
    },
  );

  test('ordinary usage cannot skip a non-empty previous unit', () async {
    await InventoryRepository.upgrade(
      database,
      2,
      InventoryRepository.schemaVersion,
    );
    final InventoryRepository repository = InventoryRepository(database);
    final int productId = await repository.saveProduct(
      actorId: 1,
      values: <String, Object?>{
        'sku': 'P-ORDER',
        'name': 'Ordered product',
        'default_unit': 'Tests',
        'after_open_days': 0,
      },
    );
    final int lotId = await repository.addLot(
      actorId: 1,
      productId: productId,
      lotNumber: 'ORDER-LOT',
    );
    final int cartonId = await repository.addCartonWithUnits(
      actorId: 1,
      lotId: lotId,
      cartonCode: 'ORDER-CARTON',
      unitCount: 2,
      quantityPerUnit: 1,
      measureUnit: 'Tests',
    );
    final List<UnitRecord> units = await repository.units(cartonId);

    await expectLater(
      repository.recordUsage(
        actorId: 1,
        unitId: units[1].id,
        quantity: 1,
        note: 'attempt to skip',
      ),
      throwsA(isA<SequentialUnitException>()),
    );

    await repository.recordUsage(
      actorId: 1,
      unitId: units[0].id,
      quantity: 1,
      note: 'finish first',
    );
    expect((await repository.unitById(units[0].id))?.openedAt, isNotNull);
    await repository.recordUsage(
      actorId: 1,
      unitId: units[1].id,
      quantity: 1,
      note: 'use second',
    );
    expect((await repository.unitById(units[1].id))?.isEmpty, isTrue);
  });

  test('opening a unit applies hour stability exactly', () async {
    await InventoryRepository.upgrade(
      database,
      2,
      InventoryRepository.schemaVersion,
    );
    final InventoryRepository repository = InventoryRepository(database);
    final int productId = await repository.saveProduct(
      actorId: 1,
      values: <String, Object?>{
        'sku': 'P-HOUR',
        'name': 'Hourly stability',
        'default_unit': 'mL',
        'after_open_days': 0,
        'stability_enabled': 1,
        'stability_value': 5,
        'stability_period': 'hour',
      },
    );
    final int lotId = await repository.addLot(
      actorId: 1,
      productId: productId,
      lotNumber: 'HOUR-LOT',
    );
    final int cartonId = await repository.addCartonWithUnits(
      actorId: 1,
      lotId: lotId,
      cartonCode: 'HOUR-CARTON',
      unitCount: 1,
      quantityPerUnit: 10,
      measureUnit: 'mL',
    );
    final UnitRecord unit = (await repository.units(cartonId)).single;
    final DateTime opened = DateTime(2026, 7, 23, 8, 30);

    await repository.openUnit(actorId: 1, unitId: unit.id, openedAt: opened);
    expect(
      (await repository.unitById(unit.id))?.afterOpenExpiry,
      DateTime(2026, 7, 23, 13, 30),
    );
  });

  test('usage is rejected after precise after-open expiry', () async {
    await InventoryRepository.upgrade(
      database,
      2,
      InventoryRepository.schemaVersion,
    );
    final InventoryRepository repository = InventoryRepository(database);
    final int productId = await repository.saveProduct(
      actorId: 1,
      values: <String, Object?>{
        'sku': 'P-EXPIRED-HOUR',
        'name': 'Expired hourly stability',
        'default_unit': 'mL',
        'after_open_days': 0,
        'stability_enabled': 1,
        'stability_value': 5,
        'stability_period': 'hour',
      },
    );
    final int lotId = await repository.addLot(
      actorId: 1,
      productId: productId,
      lotNumber: 'EXPIRED-HOUR-LOT',
    );
    final int cartonId = await repository.addCartonWithUnits(
      actorId: 1,
      lotId: lotId,
      cartonCode: 'EXPIRED-HOUR-CARTON',
      unitCount: 1,
      quantityPerUnit: 10,
      measureUnit: 'mL',
    );
    final UnitRecord unit = (await repository.units(cartonId)).single;
    await repository.openUnit(
      actorId: 1,
      unitId: unit.id,
      openedAt: DateTime.now().subtract(const Duration(hours: 6)),
    );

    await expectLater(
      repository.recordUsage(
        actorId: 1,
        unitId: unit.id,
        quantity: 1,
        note: 'must be rejected',
      ),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'UNIT_EXPIRED',
        ),
      ),
    );
  });
}

Future<void> _createLegacySchema(Database db) async {
  await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      full_name TEXT NOT NULL
    )
  ''');
  await db.insert('users', <String, Object?>{'id': 1, 'full_name': 'Admin'});

  await db.execute('''
    CREATE TABLE materials (
      id INTEGER PRIMARY KEY,
      internal_no TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      raw_barcode_value TEXT,
      gtin TEXT,
      lot_number TEXT,
      serial_number TEXT,
      catalog_number TEXT,
      department TEXT,
      storage_location TEXT,
      manufacturer TEXT,
      original_quantity REAL NOT NULL,
      used_quantity REAL NOT NULL,
      unit TEXT NOT NULL,
      received_at TEXT,
      manufacturer_expiry TEXT,
      opened_at TEXT,
      after_open_expiry TEXT,
      status TEXT,
      is_disposed INTEGER NOT NULL DEFAULT 0,
      is_blocked INTEGER NOT NULL DEFAULT 0,
      deleted_at TEXT,
      created_by INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_by INTEGER,
      updated_at TEXT,
      last_used_by INTEGER,
      last_used_at TEXT,
      sync_status TEXT NOT NULL DEFAULT 'local'
    )
  ''');

  await db.execute('''
    CREATE TABLE usage_records (
      id INTEGER PRIMARY KEY,
      material_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id INTEGER,
      action TEXT NOT NULL,
      old_value TEXT,
      new_value TEXT,
      reason TEXT,
      performed_by INTEGER NOT NULL,
      affected_user_id INTEGER,
      performed_at TEXT NOT NULL,
      device_name TEXT,
      sync_status TEXT NOT NULL DEFAULT 'local'
    )
  ''');
}

Future<void> _insertLegacyMaterial(Database db) async {
  await db.insert('materials', <String, Object?>{
    'id': 42,
    'internal_no': 'MAT-0042',
    'name': 'Control reagent',
    'type': 'Reagent',
    'raw_barcode_value': '(01)00380740150005(10)LOT-A',
    'gtin': '00380740150005',
    'lot_number': 'LOT-A',
    'serial_number': 'SER-42',
    'catalog_number': 'CAT-42',
    'department': 'Chemistry',
    'storage_location': 'Fridge 2',
    'manufacturer': 'Vendor',
    'original_quantity': 50.0,
    'used_quantity': 5.0,
    'unit': 'mL',
    'received_at': '2025-12-01T00:00:00.000',
    'manufacturer_expiry': '2026-12-31T00:00:00.000',
    'opened_at': '2026-01-01T00:00:00.000',
    'after_open_expiry': '2026-01-31T00:00:00.000',
    'status': 'active',
    'is_disposed': 0,
    'is_blocked': 0,
    'created_by': 1,
    'created_at': '2025-12-01T00:00:00.000',
  });
  await db.insert('usage_records', <String, Object?>{
    'id': 7,
    'material_id': 42,
    'user_id': 1,
  });
}

Future<void> _createV5HierarchySchema(Database db) async {
  await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sku TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      type TEXT,
      gtin TEXT,
      catalog_number TEXT,
      manufacturer TEXT,
      department TEXT,
      storage_location TEXT,
      default_unit TEXT NOT NULL,
      after_open_days INTEGER NOT NULL DEFAULT 0,
      legacy_key TEXT UNIQUE,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_by INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_by INTEGER,
      updated_at TEXT,
      sync_status TEXT NOT NULL DEFAULT 'local'
    )
  ''');
  await db.execute('''
    CREATE TABLE lots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      lot_number TEXT NOT NULL,
      manufacturer_expiry TEXT,
      received_at TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      created_by INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_by INTEGER,
      updated_at TEXT,
      sync_status TEXT NOT NULL DEFAULT 'local',
      UNIQUE(product_id, lot_number)
    )
  ''');
  await db.execute('''
    CREATE TABLE cartons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lot_id INTEGER NOT NULL,
      carton_code TEXT NOT NULL UNIQUE,
      sequence_number INTEGER NOT NULL DEFAULT 1,
      expected_unit_count INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'active',
      created_by INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_by INTEGER,
      updated_at TEXT,
      last_printed_at TEXT,
      sync_status TEXT NOT NULL DEFAULT 'local'
    )
  ''');
  await db.execute('''
    CREATE TABLE units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      carton_id INTEGER NOT NULL,
      unit_code TEXT NOT NULL UNIQUE,
      source_barcode TEXT,
      serial_number TEXT,
      original_quantity REAL NOT NULL DEFAULT 0,
      used_quantity REAL NOT NULL DEFAULT 0,
      measure_unit TEXT NOT NULL,
      opened_at TEXT,
      after_open_expiry TEXT,
      status TEXT NOT NULL DEFAULT 'sealed',
      legacy_material_id INTEGER UNIQUE,
      created_by INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_by INTEGER,
      updated_at TEXT,
      last_used_by INTEGER,
      last_used_at TEXT,
      last_printed_at TEXT,
      sync_status TEXT NOT NULL DEFAULT 'local'
    )
  ''');
}
