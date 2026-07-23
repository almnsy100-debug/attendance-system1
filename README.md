# SmartChem Track v5.1

SmartChem Track is a Flutter/SQLite laboratory inventory application. The
tracked Flutter project lives in `smartchem_v5/` and keeps the Android
application ID `om.smartchem.track.production` so existing installations can
upgrade without changing the database location.

## Inventory hierarchy

Version 5 models inventory as:

`Product → LOT → Carton → Unit`

- Products hold identity, Abbott List No, MOH Code, device, default measure
  unit, and an optional stability period in hours, days, weeks, or months.
- LOTs hold manufacturer expiry and receipt dates.
- Cartons receive a unique code and create their child units in one
  transaction.
- Units are numbered sequentially as `<carton>-001`, `<carton>-002`, and so
  on. Opening time is recorded on first usage, and ordinary users cannot skip
  a non-empty earlier unit.
- Carton and unit labels are generated as printable PDFs with Code 128
  barcodes and embedded Arabic font support.

## Data migration

The database file remains `smartchem_track_v4.db`. Schema version 6 creates
new hierarchy tables without dropping `materials`, `usage_records`, users, or
audit data. Every legacy material is copied to a linked unit through
`legacy_material_id`, and legacy usage rows receive a `unit_id` link. The
migration is idempotent and covered by an in-memory SQLite regression test.

## Barcode intake and Excel catalog

When the main user scans an unknown barcode, the application displays the
generated internal number, original barcode, GTIN, LOT, catalog number,
receipt date, and manufacturer expiry as read-only captured data. Required
registration fields use form validation and red error borders.

The material dropdown is populated from an imported `.xlsx` workbook. The
first sheet must have a material-name column and can include the two mapping
columns:

- `Material Name` (also accepts `Product Name`, `Name`, `Description`, or
  `اسم المادة`)
- `Abbott List No`
- `MOH Code`

Selecting a material fills Abbott List No and MOH Code automatically. Existing
product names are retained as catalog entries during migration.

## Validate and build

```text
cd smartchem_v5
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to
`smartchem_v5/build/app/outputs/flutter-apk/app-debug.apk`.
