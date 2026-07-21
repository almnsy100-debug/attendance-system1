import 'dart:math';

DateTime? inventoryDate(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text);
}

double inventoryNumber(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.sku,
    required this.name,
    required this.type,
    required this.gtin,
    required this.catalogNumber,
    required this.manufacturer,
    required this.department,
    required this.storageLocation,
    required this.defaultUnit,
    required this.afterOpenDays,
    required this.lotCount,
    required this.cartonCount,
    required this.unitCount,
    required this.isArchived,
    required this.createdAt,
  });

  factory ProductRecord.fromMap(Map<String, Object?> map) {
    return ProductRecord(
      id: map['id'] as int,
      sku: map['sku']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      gtin: map['gtin']?.toString() ?? '',
      catalogNumber: map['catalog_number']?.toString() ?? '',
      manufacturer: map['manufacturer']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      storageLocation: map['storage_location']?.toString() ?? '',
      defaultUnit: map['default_unit']?.toString() ?? '',
      afterOpenDays: map['after_open_days'] as int? ?? 0,
      lotCount: map['lot_count'] as int? ?? 0,
      cartonCount: map['carton_count'] as int? ?? 0,
      unitCount: map['unit_count'] as int? ?? 0,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: inventoryDate(map['created_at']),
    );
  }

  final int id;
  final String sku;
  final String name;
  final String type;
  final String gtin;
  final String catalogNumber;
  final String manufacturer;
  final String department;
  final String storageLocation;
  final String defaultUnit;
  final int afterOpenDays;
  final int lotCount;
  final int cartonCount;
  final int unitCount;
  final bool isArchived;
  final DateTime? createdAt;
}

class LotRecord {
  const LotRecord({
    required this.id,
    required this.productId,
    required this.productName,
    required this.lotNumber,
    required this.manufacturerExpiry,
    required this.receivedAt,
    required this.status,
    required this.cartonCount,
    required this.unitCount,
    required this.createdAt,
  });

  factory LotRecord.fromMap(Map<String, Object?> map) {
    return LotRecord(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name']?.toString() ?? '',
      lotNumber: map['lot_number']?.toString() ?? '',
      manufacturerExpiry: inventoryDate(map['manufacturer_expiry']),
      receivedAt: inventoryDate(map['received_at']),
      status: map['status']?.toString() ?? 'active',
      cartonCount: map['carton_count'] as int? ?? 0,
      unitCount: map['unit_count'] as int? ?? 0,
      createdAt: inventoryDate(map['created_at']),
    );
  }

  final int id;
  final int productId;
  final String productName;
  final String lotNumber;
  final DateTime? manufacturerExpiry;
  final DateTime? receivedAt;
  final String status;
  final int cartonCount;
  final int unitCount;
  final DateTime? createdAt;

  bool get isExpired {
    final DateTime? expiry = manufacturerExpiry;
    if (expiry == null) return false;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return expiry.isBefore(today);
  }
}

class CartonRecord {
  const CartonRecord({
    required this.id,
    required this.lotId,
    required this.productId,
    required this.productName,
    required this.lotNumber,
    required this.manufacturerExpiry,
    required this.cartonCode,
    required this.sequenceNumber,
    required this.expectedUnitCount,
    required this.actualUnitCount,
    required this.openUnitCount,
    required this.status,
    required this.createdAt,
    required this.lastPrintedAt,
  });

  factory CartonRecord.fromMap(Map<String, Object?> map) {
    return CartonRecord(
      id: map['id'] as int,
      lotId: map['lot_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name']?.toString() ?? '',
      lotNumber: map['lot_number']?.toString() ?? '',
      manufacturerExpiry: inventoryDate(map['manufacturer_expiry']),
      cartonCode: map['carton_code']?.toString() ?? '',
      sequenceNumber: map['sequence_number'] as int? ?? 0,
      expectedUnitCount: map['expected_unit_count'] as int? ?? 0,
      actualUnitCount: map['actual_unit_count'] as int? ?? 0,
      openUnitCount: map['open_unit_count'] as int? ?? 0,
      status: map['status']?.toString() ?? 'active',
      createdAt: inventoryDate(map['created_at']),
      lastPrintedAt: inventoryDate(map['last_printed_at']),
    );
  }

  final int id;
  final int lotId;
  final int productId;
  final String productName;
  final String lotNumber;
  final DateTime? manufacturerExpiry;
  final String cartonCode;
  final int sequenceNumber;
  final int expectedUnitCount;
  final int actualUnitCount;
  final int openUnitCount;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastPrintedAt;
}

class UnitRecord {
  const UnitRecord({
    required this.id,
    required this.cartonId,
    required this.lotId,
    required this.productId,
    required this.productName,
    required this.lotNumber,
    required this.cartonCode,
    required this.unitCode,
    required this.sourceBarcode,
    required this.serialNumber,
    required this.originalQuantity,
    required this.usedQuantity,
    required this.measureUnit,
    required this.openedAt,
    required this.afterOpenExpiry,
    required this.manufacturerExpiry,
    required this.status,
    required this.afterOpenDays,
    required this.legacyMaterialId,
    required this.createdAt,
    required this.lastPrintedAt,
  });

  factory UnitRecord.fromMap(Map<String, Object?> map) {
    return UnitRecord(
      id: map['id'] as int,
      cartonId: map['carton_id'] as int,
      lotId: map['lot_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name']?.toString() ?? '',
      lotNumber: map['lot_number']?.toString() ?? '',
      cartonCode: map['carton_code']?.toString() ?? '',
      unitCode: map['unit_code']?.toString() ?? '',
      sourceBarcode: map['source_barcode']?.toString() ?? '',
      serialNumber: map['serial_number']?.toString() ?? '',
      originalQuantity: inventoryNumber(map['original_quantity']),
      usedQuantity: inventoryNumber(map['used_quantity']),
      measureUnit: map['measure_unit']?.toString() ?? '',
      openedAt: inventoryDate(map['opened_at']),
      afterOpenExpiry: inventoryDate(map['after_open_expiry']),
      manufacturerExpiry: inventoryDate(map['manufacturer_expiry']),
      status: map['status']?.toString() ?? 'sealed',
      afterOpenDays: map['after_open_days'] as int? ?? 0,
      legacyMaterialId: map['legacy_material_id'] as int?,
      createdAt: inventoryDate(map['created_at']),
      lastPrintedAt: inventoryDate(map['last_printed_at']),
    );
  }

  final int id;
  final int cartonId;
  final int lotId;
  final int productId;
  final String productName;
  final String lotNumber;
  final String cartonCode;
  final String unitCode;
  final String sourceBarcode;
  final String serialNumber;
  final double originalQuantity;
  final double usedQuantity;
  final String measureUnit;
  final DateTime? openedAt;
  final DateTime? afterOpenExpiry;
  final DateTime? manufacturerExpiry;
  final String status;
  final int afterOpenDays;
  final int? legacyMaterialId;
  final DateTime? createdAt;
  final DateTime? lastPrintedAt;

  double get remainingQuantity => max(0, originalQuantity - usedQuantity);

  DateTime? get effectiveExpiry {
    final DateTime? openExpiry = afterOpenExpiry;
    final DateTime? lotExpiry = manufacturerExpiry;
    if (openExpiry == null) return lotExpiry;
    if (lotExpiry == null) return openExpiry;
    return openExpiry.isBefore(lotExpiry) ? openExpiry : lotExpiry;
  }

  bool get isExpired {
    final DateTime? expiry = effectiveExpiry;
    if (expiry == null) return false;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return expiry.isBefore(today);
  }

  bool get isOpened => openedAt != null;
  bool get isEmpty => remainingQuantity <= 0 || status == 'empty';
}
