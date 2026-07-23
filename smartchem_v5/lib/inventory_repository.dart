import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'inventory_models.dart';

class InventoryRepository {
  InventoryRepository(this.database);

  static const int schemaVersion = 6;

  final Database database;

  static String _now() => DateTime.now().toIso8601String();

  static Future<bool> _tableExists(Database db, String table) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      <Object?>[table],
    );
    return rows.isNotEmpty;
  }

  static Future<bool> _hasColumn(
    Database db,
    String table,
    String column,
  ) async {
    if (!await _tableExists(db, table)) return false;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'PRAGMA table_info($table)',
    );
    return rows.any((Map<String, Object?> row) => row['name'] == column);
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    if (!await _hasColumn(db, table, column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        type TEXT,
        gtin TEXT,
        catalog_number TEXT,
        abbott_list_no TEXT,
        moh_code TEXT,
        manufacturer TEXT,
        department TEXT,
        device_name TEXT,
        storage_location TEXT,
        default_unit TEXT NOT NULL,
        after_open_days INTEGER NOT NULL DEFAULT 0,
        stability_enabled INTEGER NOT NULL DEFAULT 0,
        stability_value INTEGER NOT NULL DEFAULT 0,
        stability_period TEXT NOT NULL DEFAULT 'day',
        legacy_key TEXT UNIQUE,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_by INTEGER,
        updated_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'local',
        FOREIGN KEY(created_by) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        abbott_list_no TEXT,
        moh_code TEXT,
        source_file TEXT,
        imported_at TEXT NOT NULL,
        imported_by INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lots (
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
        UNIQUE(product_id, lot_number),
        FOREIGN KEY(product_id) REFERENCES products(id),
        FOREIGN KEY(created_by) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cartons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lot_id INTEGER NOT NULL,
        carton_code TEXT NOT NULL UNIQUE,
        source_barcode TEXT,
        barcode_format TEXT,
        sequence_number INTEGER NOT NULL DEFAULT 1,
        expected_unit_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_by INTEGER,
        updated_at TEXT,
        last_printed_at TEXT,
        sync_status TEXT NOT NULL DEFAULT 'local',
        FOREIGN KEY(lot_id) REFERENCES lots(id),
        FOREIGN KEY(created_by) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carton_id INTEGER NOT NULL,
        unit_code TEXT NOT NULL UNIQUE,
        sequence_number INTEGER NOT NULL DEFAULT 1,
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
        sync_status TEXT NOT NULL DEFAULT 'local',
        FOREIGN KEY(carton_id) REFERENCES cartons(id),
        FOREIGN KEY(legacy_material_id) REFERENCES materials(id),
        FOREIGN KEY(created_by) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS unit_usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        used_quantity REAL NOT NULL,
        previous_used_quantity REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'local',
        FOREIGN KEY(unit_id) REFERENCES units(id),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS label_prints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        copies INTEGER NOT NULL DEFAULT 1,
        printed_by INTEGER NOT NULL,
        printed_at TEXT NOT NULL,
        FOREIGN KEY(printed_by) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        description TEXT NOT NULL,
        applied_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_lots_product ON lots(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_cartons_lot ON cartons(lot_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_units_carton ON units(carton_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_units_source_barcode '
      'ON units(source_barcode)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_unit_usage_unit '
      'ON unit_usage_records(unit_id)',
    );
  }

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      if (!await _hasColumn(db, 'materials', 'sync_status')) {
        await db.execute(
          "ALTER TABLE materials ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'local'",
        );
      }
      if (!await _hasColumn(db, 'audit_logs', 'sync_status')) {
        await db.execute(
          "ALTER TABLE audit_logs ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'local'",
        );
      }
    }

    await createSchema(db);

    await _upgradeToV6(db);

    if (await _tableExists(db, 'usage_records') &&
        !await _hasColumn(db, 'usage_records', 'unit_id')) {
      await db.execute('ALTER TABLE usage_records ADD COLUMN unit_id INTEGER');
    }

    await _migrateLegacyMaterials(db);
    await _syncCatalogFromProducts(db);

    if (await _hasColumn(db, 'usage_records', 'unit_id')) {
      await db.execute('''
        UPDATE usage_records
        SET unit_id = (
          SELECT u.id FROM units u
          WHERE u.legacy_material_id = usage_records.material_id
        )
        WHERE unit_id IS NULL
      ''');
    }

    await db.insert('schema_migrations', <String, Object?>{
      'version': newVersion,
      'description':
          'Inventory intake, catalog mapping, precise stability and unit order',
      'applied_at': _now(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _upgradeToV6(Database db) async {
    await _addColumnIfMissing(db, 'products', 'abbott_list_no', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'moh_code', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'device_name', 'TEXT');
    await _addColumnIfMissing(
      db,
      'products',
      'stability_enabled',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'products',
      'stability_value',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'products',
      'stability_period',
      "TEXT NOT NULL DEFAULT 'day'",
    );
    await _addColumnIfMissing(db, 'cartons', 'source_barcode', 'TEXT');
    await _addColumnIfMissing(db, 'cartons', 'barcode_format', 'TEXT');
    await _addColumnIfMissing(
      db,
      'units',
      'sequence_number',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_cartons_source_barcode '
      'ON cartons(source_barcode)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_units_carton_sequence '
      'ON units(carton_id, sequence_number)',
    );

    await db.execute('''
      UPDATE products
      SET stability_enabled = 1,
          stability_value = after_open_days,
          stability_period = 'day'
      WHERE after_open_days > 0 AND stability_enabled = 0
    ''');

    final List<Map<String, Object?>> cartons = await db.query(
      'cartons',
      columns: <String>['id'],
    );
    for (final Map<String, Object?> carton in cartons) {
      final int cartonId = carton['id'] as int;
      final List<Map<String, Object?>> units = await db.query(
        'units',
        columns: <String>['id'],
        where: 'carton_id = ?',
        whereArgs: <Object?>[cartonId],
        orderBy: 'id ASC',
      );
      for (int index = 0; index < units.length; index++) {
        await db.update(
          'units',
          <String, Object?>{'sequence_number': index + 1},
          where: 'id = ?',
          whereArgs: <Object?>[units[index]['id']],
        );
      }
    }

    await db.execute(
      '''
      INSERT OR IGNORE INTO product_catalog
        (name, abbott_list_no, moh_code, source_file, imported_at)
      SELECT name, abbott_list_no, moh_code, 'database migration', ?
      FROM products
      WHERE TRIM(name) <> ''
    ''',
      <Object?>[_now()],
    );
  }

  static Future<void> _syncCatalogFromProducts(Database db) async {
    await db.execute(
      '''
      INSERT OR IGNORE INTO product_catalog
        (name, abbott_list_no, moh_code, source_file, imported_at)
      SELECT name, abbott_list_no, moh_code, 'database migration', ?
      FROM products
      WHERE TRIM(name) <> ''
    ''',
      <Object?>[_now()],
    );
  }

  static int _inferredAfterOpenDays(Map<String, Object?> material) {
    final DateTime? opened = inventoryDate(material['opened_at']);
    final DateTime? expiry = inventoryDate(material['after_open_expiry']);
    if (opened == null || expiry == null || expiry.isBefore(opened)) return 0;
    return expiry.difference(opened).inDays;
  }

  static Future<void> _migrateLegacyMaterials(Database db) async {
    if (!await _tableExists(db, 'materials')) return;

    final List<Map<String, Object?>> materials = await db.query(
      'materials',
      orderBy: 'id ASC',
    );

    for (final Map<String, Object?> material in materials) {
      final int materialId = material['id'] as int;
      final String gtin = material['gtin']?.toString().trim() ?? '';
      final String catalog =
          material['catalog_number']?.toString().trim() ?? '';
      final String name = material['name']?.toString().trim() ?? '';
      final String manufacturer =
          material['manufacturer']?.toString().trim() ?? '';
      final String legacyKey =
          gtin.isNotEmpty
              ? 'GTIN:$gtin'
              : catalog.isNotEmpty
              ? 'CAT:$catalog'
              : 'NAME:${name.toLowerCase()}|${manufacturer.toLowerCase()}';
      final int stabilityDays = _inferredAfterOpenDays(material);

      List<Map<String, Object?>> rows = await db.query(
        'products',
        where: 'legacy_key = ?',
        whereArgs: <Object?>[legacyKey],
        limit: 1,
      );

      late int productId;
      if (rows.isEmpty) {
        productId = await db.insert('products', <String, Object?>{
          'sku': material['internal_no']?.toString() ?? 'LEGACY-$materialId',
          'name': name.isEmpty ? 'Legacy product $materialId' : name,
          'type': material['type'],
          'gtin': gtin,
          'catalog_number': catalog,
          'manufacturer': manufacturer,
          'department': material['department'],
          'device_name': material['device_name'],
          'storage_location': material['storage_location'],
          'default_unit': material['unit']?.toString() ?? '',
          'after_open_days': stabilityDays,
          'stability_enabled': stabilityDays > 0 ? 1 : 0,
          'stability_value': stabilityDays,
          'stability_period': 'day',
          'legacy_key': legacyKey,
          'is_archived': material['deleted_at'] == null ? 0 : 1,
          'created_by': material['created_by'],
          'created_at': material['created_at'] ?? _now(),
          'updated_by': material['updated_by'],
          'updated_at': material['updated_at'],
          'sync_status': 'local',
        });
      } else {
        productId = rows.first['id'] as int;
        final int currentDays = rows.first['after_open_days'] as int? ?? 0;
        if (currentDays == 0 && stabilityDays > 0) {
          await db.update(
            'products',
            <String, Object?>{'after_open_days': stabilityDays},
            where: 'id = ?',
            whereArgs: <Object?>[productId],
          );
        }
      }

      final String sourceLot = material['lot_number']?.toString().trim() ?? '';
      final String lotNumber =
          sourceLot.isEmpty ? 'LEGACY-LOT-$materialId' : sourceLot;
      rows = await db.query(
        'lots',
        where: 'product_id = ? AND lot_number = ?',
        whereArgs: <Object?>[productId, lotNumber],
        limit: 1,
      );
      final int lotId =
          rows.isEmpty
              ? await db.insert('lots', <String, Object?>{
                'product_id': productId,
                'lot_number': lotNumber,
                'manufacturer_expiry': material['manufacturer_expiry'],
                'received_at': material['received_at'],
                'status':
                    material['deleted_at'] == null ? 'active' : 'archived',
                'created_by': material['created_by'],
                'created_at': material['created_at'] ?? _now(),
                'sync_status': 'local',
              })
              : rows.first['id'] as int;

      final String cartonCode = 'LEGACY-CARTON-$materialId';
      rows = await db.query(
        'cartons',
        where: 'carton_code = ?',
        whereArgs: <Object?>[cartonCode],
        limit: 1,
      );
      final int cartonId =
          rows.isEmpty
              ? await db.insert('cartons', <String, Object?>{
                'lot_id': lotId,
                'carton_code': cartonCode,
                'sequence_number': 1,
                'expected_unit_count': 1,
                'status':
                    material['deleted_at'] == null ? 'active' : 'archived',
                'created_by': material['created_by'],
                'created_at': material['created_at'] ?? _now(),
                'sync_status': 'local',
              })
              : rows.first['id'] as int;

      rows = await db.query(
        'units',
        where: 'legacy_material_id = ?',
        whereArgs: <Object?>[materialId],
        limit: 1,
      );
      if (rows.isNotEmpty) continue;

      final double original = inventoryNumber(material['original_quantity']);
      final double used = inventoryNumber(material['used_quantity']);
      String status = 'sealed';
      if (material['deleted_at'] != null) {
        status = 'archived';
      } else if ((material['is_disposed'] as int? ?? 0) == 1) {
        status = 'disposed';
      } else if (used >= original || material['status'] == 'empty') {
        status = 'empty';
      } else if (material['opened_at'] != null || used > 0) {
        status = 'opened';
      } else if ((material['is_blocked'] as int? ?? 0) == 1) {
        status = 'blocked';
      }

      await db.insert('units', <String, Object?>{
        'carton_id': cartonId,
        'unit_code': 'SCU-LEGACY-$materialId',
        'source_barcode': material['raw_barcode_value'],
        'serial_number': material['serial_number'],
        'original_quantity': original,
        'used_quantity': used,
        'measure_unit': material['unit']?.toString() ?? '',
        'opened_at': material['opened_at'],
        'after_open_expiry': material['after_open_expiry'],
        'status': status,
        'legacy_material_id': materialId,
        'created_by': material['created_by'],
        'created_at': material['created_at'] ?? _now(),
        'updated_by': material['updated_by'],
        'updated_at': material['updated_at'],
        'last_used_by': material['last_used_by'],
        'last_used_at': material['last_used_at'],
        'sync_status': 'local',
      });
    }
  }

  Future<void> _audit({
    required int actorId,
    required String entityType,
    required int entityId,
    required String action,
    Object? value,
    String? reason,
  }) async {
    await database.insert('audit_logs', <String, Object?>{
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'new_value': value == null ? null : jsonEncode(value),
      'reason': reason,
      'performed_by': actorId,
      'performed_at': _now(),
      'device_name': 'SmartChem Track v5',
      'sync_status': 'local',
    });
  }

  Future<List<ProductCatalogRecord>> productCatalog() async {
    final List<Map<String, Object?>> rows = await database.query(
      'product_catalog',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(ProductCatalogRecord.fromMap).toList();
  }

  Future<ProductRecord?> productForCatalog(
    ProductCatalogRecord catalogEntry,
  ) async {
    final List<ProductRecord> existing = await products();
    for (final ProductRecord product in existing) {
      if (catalogEntry.abbottListNo.isNotEmpty &&
          product.abbottListNo == catalogEntry.abbottListNo) {
        return product;
      }
      if (catalogEntry.mohCode.isNotEmpty &&
          product.mohCode == catalogEntry.mohCode) {
        return product;
      }
      if (product.name.toLowerCase() == catalogEntry.name.toLowerCase()) {
        return product;
      }
    }
    return null;
  }

  Future<int> importProductCatalog({
    required int actorId,
    required String sourceFile,
    required List<Map<String, String>> rows,
  }) async {
    int imported = 0;
    await database.transaction((Transaction transaction) async {
      for (final Map<String, String> row in rows) {
        final String name = row['name']?.trim() ?? '';
        if (name.isEmpty) continue;
        await transaction.insert('product_catalog', <String, Object?>{
          'name': name,
          'abbott_list_no': row['abbott_list_no']?.trim() ?? '',
          'moh_code': row['moh_code']?.trim() ?? '',
          'source_file': sourceFile,
          'imported_at': _now(),
          'imported_by': actorId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        imported++;
      }
      await transaction.insert('audit_logs', <String, Object?>{
        'entity_type': 'product_catalog',
        'action': 'IMPORT_PRODUCT_CATALOG',
        'new_value': jsonEncode(<String, Object?>{
          'source_file': sourceFile,
          'rows': imported,
        }),
        'performed_by': actorId,
        'performed_at': _now(),
        'device_name': 'SmartChem Track v6',
        'sync_status': 'local',
      });
    });
    return imported;
  }

  Future<String> nextInternalNumber() async {
    final int next =
        Sqflite.firstIntValue(
          await database.rawQuery(
            'SELECT COALESCE(MAX(id), 0) + 1 FROM products',
          ),
        ) ??
        1;
    final DateTime now = DateTime.now();
    final String date =
        '${(now.year % 100).toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'SC-$date-${next.toString().padLeft(4, '0')}';
  }

  Future<String> suggestCartonCode({
    required String preferred,
    required String internalNumber,
    required String lotNumber,
  }) async {
    String sanitize(String value) {
      return value
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9_-]+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
    }

    final String preferredCode = sanitize(preferred);
    final String fallback = '${sanitize(internalNumber)}-${sanitize(lotNumber)}'
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final String base =
        preferredCode.isNotEmpty
            ? preferredCode
            : fallback.isNotEmpty
            ? fallback
            : 'SC-CARTON';
    String candidate = base;
    int suffix = 2;
    while ((await database.query(
      'cartons',
      columns: <String>['id'],
      where: 'carton_code = ?',
      whereArgs: <Object?>[candidate],
      limit: 1,
    )).isNotEmpty) {
      candidate = '$base-${suffix.toString().padLeft(3, '0')}';
      suffix++;
    }
    return candidate;
  }

  Future<InventoryIntakeResult> createInventoryIntake({
    required int actorId,
    required String internalNumber,
    required String rawBarcode,
    required String barcodeFormat,
    required String gtin,
    required String lotNumber,
    required String catalogNumber,
    required DateTime receivedAt,
    required DateTime? manufacturerExpiry,
    required String cartonCode,
    required int unitCount,
    required ProductCatalogRecord catalogEntry,
    required String materialType,
    required String department,
    required String deviceName,
    required String storageLocation,
    required String measureUnit,
    required bool stabilityEnabled,
    required int stabilityValue,
    required String stabilityPeriod,
  }) async {
    if (unitCount < 1 || unitCount > 1000) {
      throw ArgumentError('INVALID_UNIT_COUNT');
    }
    if (stabilityEnabled &&
        (stabilityValue <= 0 ||
            !inventoryStabilityPeriods.contains(stabilityPeriod))) {
      throw ArgumentError('INVALID_STABILITY');
    }
    return database.transaction((Transaction transaction) async {
      List<Map<String, Object?>> products = await transaction.query(
        'products',
        where:
            '(abbott_list_no <> ? AND abbott_list_no = ?) OR '
            '(moh_code <> ? AND moh_code = ?) OR name = ? COLLATE NOCASE',
        whereArgs: <Object?>[
          '',
          catalogEntry.abbottListNo,
          '',
          catalogEntry.mohCode,
          catalogEntry.name,
        ],
        orderBy: 'id ASC',
        limit: 1,
      );
      late int productId;
      final Map<String, Object?>? existingProduct =
          products.isEmpty ? null : products.first;
      String existingValue(String key) {
        if (existingProduct == null) return '';
        return existingProduct[key]?.toString() ?? '';
      }

      final int legacyDays =
          stabilityEnabled
              ? stabilityPeriod == 'day'
                  ? stabilityValue
                  : stabilityPeriod == 'week'
                  ? stabilityValue * 7
                  : stabilityPeriod == 'month'
                  ? stabilityValue * 30
                  : 0
              : 0;
      final Map<String, Object?> productValues = <String, Object?>{
        'name': catalogEntry.name,
        'type': materialType,
        'gtin': gtin.trim().isEmpty ? existingValue('gtin') : gtin.trim(),
        'catalog_number':
            catalogNumber.trim().isEmpty
                ? existingValue('catalog_number')
                : catalogNumber.trim(),
        'abbott_list_no':
            catalogEntry.abbottListNo.isEmpty
                ? existingValue('abbott_list_no')
                : catalogEntry.abbottListNo,
        'moh_code':
            catalogEntry.mohCode.isEmpty
                ? existingValue('moh_code')
                : catalogEntry.mohCode,
        'department': department,
        'device_name': deviceName,
        'storage_location': storageLocation,
        'default_unit': measureUnit,
        'after_open_days': legacyDays,
        'stability_enabled': stabilityEnabled ? 1 : 0,
        'stability_value': stabilityEnabled ? stabilityValue : 0,
        'stability_period': stabilityPeriod,
        'updated_by': actorId,
        'updated_at': _now(),
        'sync_status': 'local',
      };
      if (products.isEmpty) {
        productId = await transaction.insert('products', <String, Object?>{
          ...productValues,
          'sku': internalNumber.trim(),
          'is_archived': 0,
          'created_by': actorId,
          'created_at': _now(),
        });
      } else {
        productId = products.first['id'] as int;
        await transaction.update(
          'products',
          productValues,
          where: 'id = ?',
          whereArgs: <Object?>[productId],
        );
      }

      final String normalizedLot =
          lotNumber.trim().isEmpty
              ? 'NO-LOT-${DateTime.now().millisecondsSinceEpoch}'
              : lotNumber.trim();
      List<Map<String, Object?>> lots = await transaction.query(
        'lots',
        where: 'product_id = ? AND lot_number = ?',
        whereArgs: <Object?>[productId, normalizedLot],
        limit: 1,
      );
      late int lotId;
      if (lots.isEmpty) {
        lotId = await transaction.insert('lots', <String, Object?>{
          'product_id': productId,
          'lot_number': normalizedLot,
          'manufacturer_expiry': manufacturerExpiry?.toIso8601String(),
          'received_at': receivedAt.toIso8601String(),
          'status': 'active',
          'created_by': actorId,
          'created_at': _now(),
          'sync_status': 'local',
        });
      } else {
        lotId = lots.first['id'] as int;
      }

      final List<Map<String, Object?>> sequenceRows = await transaction
          .rawQuery(
            'SELECT COALESCE(MAX(sequence_number), 0) + 1 AS next FROM cartons '
            'WHERE lot_id = ?',
            <Object?>[lotId],
          );
      final int cartonSequence = sequenceRows.first['next'] as int? ?? 1;
      final int cartonId = await transaction
          .insert('cartons', <String, Object?>{
            'lot_id': lotId,
            'carton_code': cartonCode.trim(),
            'source_barcode': rawBarcode,
            'barcode_format': barcodeFormat,
            'sequence_number': cartonSequence,
            'expected_unit_count': unitCount,
            'status': 'active',
            'created_by': actorId,
            'created_at': _now(),
            'sync_status': 'local',
          });
      for (int index = 1; index <= unitCount; index++) {
        final String suffix = index.toString().padLeft(3, '0');
        final String unitCode = '${cartonCode.trim()}-$suffix';
        await transaction.insert('units', <String, Object?>{
          'carton_id': cartonId,
          'unit_code': unitCode,
          'sequence_number': index,
          'source_barcode': unitCode,
          'serial_number': unitCode,
          'original_quantity': 1,
          'used_quantity': 0,
          'measure_unit': measureUnit,
          'status': 'sealed',
          'created_by': actorId,
          'created_at': _now(),
          'sync_status': 'local',
        });
      }
      await transaction.insert('audit_logs', <String, Object?>{
        'entity_type': 'carton',
        'entity_id': cartonId,
        'action': 'SCAN_INVENTORY_INTAKE',
        'new_value': jsonEncode(<String, Object?>{
          'product_id': productId,
          'lot_id': lotId,
          'carton_code': cartonCode,
          'unit_count': unitCount,
          'raw_barcode': rawBarcode,
        }),
        'performed_by': actorId,
        'performed_at': _now(),
        'device_name': 'SmartChem Track v6',
        'sync_status': 'local',
      });
      return InventoryIntakeResult(
        productId: productId,
        lotId: lotId,
        cartonId: cartonId,
      );
    });
  }

  Future<List<ProductRecord>> products({bool includeArchived = false}) async {
    final List<Map<String, Object?>> rows = await database.rawQuery('''
      SELECT p.*,
        (SELECT COUNT(*) FROM lots l WHERE l.product_id = p.id) AS lot_count,
        (SELECT COUNT(*) FROM cartons c JOIN lots l ON l.id = c.lot_id
          WHERE l.product_id = p.id) AS carton_count,
        (SELECT COUNT(*) FROM units u
          JOIN cartons c ON c.id = u.carton_id
          JOIN lots l ON l.id = c.lot_id
          WHERE l.product_id = p.id) AS unit_count
      FROM products p
      ${includeArchived ? '' : 'WHERE p.is_archived = 0'}
      ORDER BY p.name COLLATE NOCASE
    ''');
    return rows.map(ProductRecord.fromMap).toList();
  }

  Future<ProductRecord?> productById(int productId) async {
    final List<ProductRecord> rows = await products(includeArchived: true);
    for (final ProductRecord row in rows) {
      if (row.id == productId) return row;
    }
    return null;
  }

  Future<int> saveProduct({
    required int actorId,
    required Map<String, Object?> values,
    int? productId,
  }) async {
    final Map<String, Object?> saved = <String, Object?>{
      ...values,
      'updated_by': actorId,
      'updated_at': _now(),
      'sync_status': 'local',
    };
    if (!saved.containsKey('stability_enabled') &&
        saved.containsKey('after_open_days')) {
      final int days = saved['after_open_days'] as int? ?? 0;
      saved['stability_enabled'] = days > 0 ? 1 : 0;
      saved['stability_value'] = days;
      saved['stability_period'] = 'day';
    }
    late int id;
    if (productId == null) {
      saved['created_by'] = actorId;
      saved['created_at'] = _now();
      id = await database.insert('products', saved);
    } else {
      await database.update(
        'products',
        saved,
        where: 'id = ?',
        whereArgs: <Object?>[productId],
      );
      id = productId;
    }
    await _audit(
      actorId: actorId,
      entityType: 'product',
      entityId: id,
      action: productId == null ? 'ADD_PRODUCT' : 'EDIT_PRODUCT',
      value: values,
    );
    return id;
  }

  Future<List<LotRecord>> lots(int productId) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT l.*, p.name AS product_name,
        (SELECT COUNT(*) FROM cartons c WHERE c.lot_id = l.id) AS carton_count,
        (SELECT COUNT(*) FROM units u JOIN cartons c ON c.id = u.carton_id
          WHERE c.lot_id = l.id) AS unit_count
      FROM lots l
      JOIN products p ON p.id = l.product_id
      WHERE l.product_id = ?
      ORDER BY l.created_at DESC
    ''',
      <Object?>[productId],
    );
    return rows.map(LotRecord.fromMap).toList();
  }

  Future<LotRecord?> lotById(int lotId) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT l.*, p.name AS product_name,
        (SELECT COUNT(*) FROM cartons c WHERE c.lot_id = l.id) AS carton_count,
        (SELECT COUNT(*) FROM units u JOIN cartons c ON c.id = u.carton_id
          WHERE c.lot_id = l.id) AS unit_count
      FROM lots l JOIN products p ON p.id = l.product_id
      WHERE l.id = ? LIMIT 1
    ''',
      <Object?>[lotId],
    );
    return rows.isEmpty ? null : LotRecord.fromMap(rows.first);
  }

  Future<int> addLot({
    required int actorId,
    required int productId,
    required String lotNumber,
    DateTime? manufacturerExpiry,
    DateTime? receivedAt,
  }) async {
    final int id = await database.insert('lots', <String, Object?>{
      'product_id': productId,
      'lot_number': lotNumber.trim(),
      'manufacturer_expiry': manufacturerExpiry?.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
      'status': 'active',
      'created_by': actorId,
      'created_at': _now(),
      'sync_status': 'local',
    });
    await _audit(
      actorId: actorId,
      entityType: 'lot',
      entityId: id,
      action: 'ADD_LOT',
      value: <String, Object?>{'product_id': productId, 'lot': lotNumber},
    );
    return id;
  }

  Future<List<CartonRecord>> cartons(int lotId) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT c.*, l.product_id, l.lot_number, l.manufacturer_expiry,
        p.name AS product_name,
        (SELECT COUNT(*) FROM units u WHERE u.carton_id = c.id) AS actual_unit_count,
        (SELECT COUNT(*) FROM units u WHERE u.carton_id = c.id
          AND u.opened_at IS NOT NULL) AS open_unit_count
      FROM cartons c
      JOIN lots l ON l.id = c.lot_id
      JOIN products p ON p.id = l.product_id
      WHERE c.lot_id = ?
      ORDER BY c.sequence_number, c.created_at
    ''',
      <Object?>[lotId],
    );
    return rows.map(CartonRecord.fromMap).toList();
  }

  Future<CartonRecord?> cartonById(int cartonId) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT c.*, l.product_id, l.lot_number, l.manufacturer_expiry,
        p.name AS product_name,
        (SELECT COUNT(*) FROM units u WHERE u.carton_id = c.id) AS actual_unit_count,
        (SELECT COUNT(*) FROM units u WHERE u.carton_id = c.id
          AND u.opened_at IS NOT NULL) AS open_unit_count
      FROM cartons c
      JOIN lots l ON l.id = c.lot_id
      JOIN products p ON p.id = l.product_id
      WHERE c.id = ? LIMIT 1
    ''',
      <Object?>[cartonId],
    );
    return rows.isEmpty ? null : CartonRecord.fromMap(rows.first);
  }

  Future<CartonRecord?> findCarton(String code) async {
    final String value = code.trim();
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT c.*, l.product_id, l.lot_number, l.manufacturer_expiry,
        p.name AS product_name,
        (SELECT COUNT(*) FROM units u WHERE u.carton_id = c.id) AS actual_unit_count,
        (SELECT COUNT(*) FROM units u WHERE u.carton_id = c.id
          AND u.opened_at IS NOT NULL) AS open_unit_count
      FROM cartons c
      JOIN lots l ON l.id = c.lot_id
      JOIN products p ON p.id = l.product_id
      WHERE c.carton_code = ? OR c.source_barcode = ?
      ORDER BY c.id DESC LIMIT 1
    ''',
      <Object?>[value, value],
    );
    return rows.isEmpty ? null : CartonRecord.fromMap(rows.first);
  }

  Future<int> addCartonWithUnits({
    required int actorId,
    required int lotId,
    required String cartonCode,
    required int unitCount,
    required double quantityPerUnit,
    required String measureUnit,
    String sourceBarcode = '',
    String barcodeFormat = '',
  }) async {
    if (unitCount < 1 || unitCount > 1000 || quantityPerUnit <= 0) {
      throw ArgumentError('INVALID_CARTON_QUANTITY');
    }
    return database.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> sequenceRows = await transaction
          .rawQuery(
            'SELECT COALESCE(MAX(sequence_number), 0) + 1 AS next FROM cartons '
            'WHERE lot_id = ?',
            <Object?>[lotId],
          );
      final int sequence = sequenceRows.first['next'] as int? ?? 1;
      final int cartonId = await transaction
          .insert('cartons', <String, Object?>{
            'lot_id': lotId,
            'carton_code': cartonCode.trim(),
            'source_barcode': sourceBarcode.trim(),
            'barcode_format': barcodeFormat.trim(),
            'sequence_number': sequence,
            'expected_unit_count': unitCount,
            'status': 'active',
            'created_by': actorId,
            'created_at': _now(),
            'sync_status': 'local',
          });
      for (int index = 1; index <= unitCount; index++) {
        final String suffix = index.toString().padLeft(3, '0');
        final String unitCode = '${cartonCode.trim()}-$suffix';
        await transaction.insert('units', <String, Object?>{
          'carton_id': cartonId,
          'unit_code': unitCode,
          'sequence_number': index,
          'source_barcode': unitCode,
          'serial_number': unitCode,
          'original_quantity': quantityPerUnit,
          'used_quantity': 0,
          'measure_unit': measureUnit,
          'status': 'sealed',
          'created_by': actorId,
          'created_at': _now(),
          'sync_status': 'local',
        });
      }
      await transaction.insert('audit_logs', <String, Object?>{
        'entity_type': 'carton',
        'entity_id': cartonId,
        'action': 'ADD_CARTON_WITH_UNITS',
        'new_value': jsonEncode(<String, Object?>{
          'lot_id': lotId,
          'carton_code': cartonCode,
          'unit_count': unitCount,
          'quantity_per_unit': quantityPerUnit,
        }),
        'performed_by': actorId,
        'performed_at': _now(),
        'device_name': 'SmartChem Track v5',
        'sync_status': 'local',
      });
      return cartonId;
    });
  }

  Future<List<UnitRecord>> units(int cartonId) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT u.*, c.lot_id, c.carton_code, l.product_id, l.lot_number,
        l.manufacturer_expiry, p.name AS product_name,
        p.after_open_days, p.stability_enabled, p.stability_value,
        p.stability_period
      FROM units u
      JOIN cartons c ON c.id = u.carton_id
      JOIN lots l ON l.id = c.lot_id
      JOIN products p ON p.id = l.product_id
      WHERE u.carton_id = ?
      ORDER BY u.sequence_number, u.id
    ''',
      <Object?>[cartonId],
    );
    return rows.map(UnitRecord.fromMap).toList();
  }

  Future<UnitRecord?> unitById(int unitId) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT u.*, c.lot_id, c.carton_code, l.product_id, l.lot_number,
        l.manufacturer_expiry, p.name AS product_name,
        p.after_open_days, p.stability_enabled, p.stability_value,
        p.stability_period
      FROM units u
      JOIN cartons c ON c.id = u.carton_id
      JOIN lots l ON l.id = c.lot_id
      JOIN products p ON p.id = l.product_id
      WHERE u.id = ? LIMIT 1
    ''',
      <Object?>[unitId],
    );
    return rows.isEmpty ? null : UnitRecord.fromMap(rows.first);
  }

  Future<UnitRecord?> findUnit(String code) async {
    final String value = code.trim();
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT u.*, c.lot_id, c.carton_code, l.product_id, l.lot_number,
        l.manufacturer_expiry, p.name AS product_name,
        p.after_open_days, p.stability_enabled, p.stability_value,
        p.stability_period
      FROM units u
      JOIN cartons c ON c.id = u.carton_id
      JOIN lots l ON l.id = c.lot_id
      JOIN products p ON p.id = l.product_id
      WHERE u.unit_code = ? OR u.source_barcode = ? OR u.serial_number = ?
      LIMIT 1
    ''',
      <Object?>[value, value, value],
    );
    return rows.isEmpty ? null : UnitRecord.fromMap(rows.first);
  }

  Future<UnitRecord?> blockingPreviousUnit(int unitId) async {
    final List<Map<String, Object?>> rows = await database.rawQuery(
      '''
      SELECT previous.*, c.lot_id, c.carton_code, l.product_id, l.lot_number,
        l.manufacturer_expiry, p.name AS product_name,
        p.after_open_days, p.stability_enabled, p.stability_value,
        p.stability_period
      FROM units current
      JOIN units previous ON previous.carton_id = current.carton_id
        AND previous.sequence_number < current.sequence_number
      JOIN cartons c ON c.id = previous.carton_id
      JOIN lots l ON l.id = c.lot_id
      JOIN products p ON p.id = l.product_id
      WHERE current.id = ?
        AND previous.status NOT IN ('empty', 'disposed', 'archived')
        AND previous.used_quantity < previous.original_quantity
      ORDER BY previous.sequence_number ASC
    ''',
      <Object?>[unitId],
    );
    for (final Map<String, Object?> row in rows) {
      final UnitRecord unit = UnitRecord.fromMap(row);
      if (!unit.isExpired) return unit;
    }
    return null;
  }

  static DateTime? _afterOpenExpiry(
    Map<String, Object?> row,
    DateTime openedAt,
  ) {
    final bool enabled = (row['stability_enabled'] as int? ?? 0) == 1;
    final int value =
        row['stability_value'] as int? ?? row['after_open_days'] as int? ?? 0;
    if (!enabled || value <= 0) return null;
    return calculateStabilityExpiry(
      openedAt,
      value,
      row['stability_period']?.toString() ?? 'day',
    );
  }

  Future<void> openUnit({
    required int actorId,
    required int unitId,
    DateTime? openedAt,
  }) async {
    final DateTime opened = openedAt ?? DateTime.now();
    await database.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> rows = await transaction.rawQuery(
        '''
        SELECT u.opened_at, u.status, p.after_open_days,
          p.stability_enabled, p.stability_value, p.stability_period
        FROM units u
        JOIN cartons c ON c.id = u.carton_id
        JOIN lots l ON l.id = c.lot_id
        JOIN products p ON p.id = l.product_id
        WHERE u.id = ? LIMIT 1
      ''',
        <Object?>[unitId],
      );
      if (rows.isEmpty) throw StateError('UNIT_NOT_FOUND');
      if (rows.first['opened_at'] != null) return;
      final DateTime? afterOpenExpiry = _afterOpenExpiry(rows.first, opened);
      await transaction.update(
        'units',
        <String, Object?>{
          'opened_at': opened.toIso8601String(),
          'after_open_expiry': afterOpenExpiry?.toIso8601String(),
          'status': 'opened',
          'updated_by': actorId,
          'updated_at': _now(),
          'sync_status': 'local',
        },
        where: 'id = ?',
        whereArgs: <Object?>[unitId],
      );
      await transaction.insert('audit_logs', <String, Object?>{
        'entity_type': 'unit',
        'entity_id': unitId,
        'action': 'OPEN_UNIT',
        'new_value': afterOpenExpiry?.toIso8601String(),
        'performed_by': actorId,
        'performed_at': _now(),
        'device_name': 'SmartChem Track v5',
        'sync_status': 'local',
      });
    });
  }

  Future<void> recordUsage({
    required int actorId,
    required int unitId,
    required double quantity,
    required String note,
    bool enforceSequence = true,
  }) async {
    if (quantity <= 0) throw ArgumentError('INVALID_QUANTITY');
    await database.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> rows = await transaction.rawQuery(
        '''
        SELECT u.*, c.lot_id, c.carton_code, l.product_id, l.lot_number,
          l.manufacturer_expiry, p.name AS product_name, p.after_open_days,
          p.stability_enabled, p.stability_value, p.stability_period
        FROM units u
        JOIN cartons c ON c.id = u.carton_id
        JOIN lots l ON l.id = c.lot_id
        JOIN products p ON p.id = l.product_id
        WHERE u.id = ? LIMIT 1
      ''',
        <Object?>[unitId],
      );
      if (rows.isEmpty) throw StateError('UNIT_NOT_FOUND');
      final Map<String, Object?> row = rows.first;
      if (enforceSequence) {
        final List<Map<String, Object?>> blockers = await transaction.rawQuery(
          '''
          SELECT previous.*, c.lot_id, c.carton_code, l.product_id,
            l.lot_number, l.manufacturer_expiry, p.name AS product_name,
            p.after_open_days, p.stability_enabled, p.stability_value,
            p.stability_period
          FROM units current
          JOIN units previous ON previous.carton_id = current.carton_id
            AND previous.sequence_number < current.sequence_number
          JOIN cartons c ON c.id = previous.carton_id
          JOIN lots l ON l.id = c.lot_id
          JOIN products p ON p.id = l.product_id
          WHERE current.id = ?
            AND previous.status NOT IN ('empty', 'disposed', 'archived')
            AND previous.used_quantity < previous.original_quantity
          ORDER BY previous.sequence_number ASC
        ''',
          <Object?>[unitId],
        );
        for (final Map<String, Object?> blocker in blockers) {
          final UnitRecord unit = UnitRecord.fromMap(blocker);
          if (!unit.isExpired) {
            throw SequentialUnitException(unit);
          }
        }
      }
      final double original = inventoryNumber(row['original_quantity']);
      final double previous = inventoryNumber(row['used_quantity']);
      if (quantity > original - previous) {
        throw ArgumentError('INVALID_QUANTITY');
      }

      DateTime? openedAt = inventoryDate(row['opened_at']);
      DateTime? afterOpenExpiry = inventoryDate(row['after_open_expiry']);
      if (openedAt == null) {
        openedAt = DateTime.now();
        afterOpenExpiry = _afterOpenExpiry(row, openedAt);
      }
      final DateTime? lotExpiry = inventoryDate(row['manufacturer_expiry']);
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final bool stabilityExpired =
          afterOpenExpiry != null && !afterOpenExpiry.isAfter(now);
      final bool manufacturerExpired =
          lotExpiry != null && lotExpiry.isBefore(today);
      if (stabilityExpired || manufacturerExpired) {
        throw StateError('UNIT_EXPIRED');
      }

      final double total = previous + quantity;
      await transaction.insert('unit_usage_records', <String, Object?>{
        'unit_id': unitId,
        'user_id': actorId,
        'used_quantity': quantity,
        'previous_used_quantity': previous,
        'note': note.trim(),
        'created_at': _now(),
        'sync_status': 'local',
      });
      await transaction.update(
        'units',
        <String, Object?>{
          'used_quantity': total,
          'opened_at': openedAt.toIso8601String(),
          'after_open_expiry': afterOpenExpiry?.toIso8601String(),
          'status': total >= original ? 'empty' : 'opened',
          'last_used_by': actorId,
          'last_used_at': _now(),
          'updated_by': actorId,
          'updated_at': _now(),
          'sync_status': 'local',
        },
        where: 'id = ?',
        whereArgs: <Object?>[unitId],
      );
      await transaction.insert('audit_logs', <String, Object?>{
        'entity_type': 'unit',
        'entity_id': unitId,
        'action': 'ADD_UNIT_USAGE',
        'new_value': quantity.toString(),
        'reason': note,
        'performed_by': actorId,
        'performed_at': _now(),
        'device_name': 'SmartChem Track v5',
        'sync_status': 'local',
      });
    });
  }

  Future<void> recordLabelPrint({
    required int actorId,
    required String entityType,
    required int entityId,
    required int copies,
  }) async {
    final String now = _now();
    await database.transaction((Transaction transaction) async {
      await transaction.insert('label_prints', <String, Object?>{
        'entity_type': entityType,
        'entity_id': entityId,
        'copies': copies,
        'printed_by': actorId,
        'printed_at': now,
      });
      if (entityType == 'carton') {
        await transaction.update(
          'cartons',
          <String, Object?>{'last_printed_at': now},
          where: 'id = ?',
          whereArgs: <Object?>[entityId],
        );
      } else if (entityType == 'unit') {
        await transaction.update(
          'units',
          <String, Object?>{'last_printed_at': now},
          where: 'id = ?',
          whereArgs: <Object?>[entityId],
        );
      }
    });
  }
}
