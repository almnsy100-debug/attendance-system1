# SmartChem Track v5

SmartChem Track is a Flutter/SQLite laboratory inventory application. The
tracked Flutter project lives in `smartchem_v5/` and keeps the Android
application ID `om.smartchem.track.production` so existing installations can
upgrade without changing the database location.

## Inventory hierarchy

Version 5 models inventory as:

`Product → LOT → Carton → Unit`

- Products hold identity, manufacturer, default measure unit, and the
  stability period after opening.
- LOTs hold manufacturer expiry and receipt dates.
- Cartons receive a unique code and create their child units in one
  transaction.
- Units track opening, after-open expiry, effective expiry, consumption, and
  status independently.
- Carton and unit labels are generated as printable PDFs with Code 128
  barcodes and embedded Arabic font support.

## Data migration

The database file remains `smartchem_track_v4.db`. Schema version 5 creates
new hierarchy tables without dropping `materials`, `usage_records`, users, or
audit data. Every legacy material is copied to a linked unit through
`legacy_material_id`, and legacy usage rows receive a `unit_id` link. The
migration is idempotent and covered by an in-memory SQLite regression test.

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
