import 'package:flutter_test/flutter_test.dart';
import 'package:production/inventory_repository.dart';
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
      expect(product['gtin'], '00380740150005');

      final Map<String, Object?> unit = (await database.query('units')).single;
      expect(unit['legacy_material_id'], 42);
      expect(unit['original_quantity'], 50.0);
      expect(unit['used_quantity'], 5.0);
      expect(unit['opened_at'], '2026-01-01T00:00:00.000');
      expect(unit['after_open_expiry'], '2026-01-31T00:00:00.000');

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
