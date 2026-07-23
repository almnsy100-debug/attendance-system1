// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SmartChem Track';

  @override
  String get version => 'Version 5.0.0';

  @override
  String get login => 'Sign In';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get invalidLogin => 'Invalid credentials or the account is disabled';

  @override
  String get language => 'App Language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get welcome => 'Welcome';

  @override
  String get totalMaterials => 'Total Materials';

  @override
  String get available => 'Available';

  @override
  String get expiredOrEmpty => 'Expired or Empty';

  @override
  String get unused => 'Unused';

  @override
  String get scanMaterial => 'Scan Material Barcode';

  @override
  String get inventory => 'Inventory and Material Log';

  @override
  String get userManagement => 'User Management';

  @override
  String get auditTrail => 'Audit Trail';

  @override
  String get logout => 'Sign Out';

  @override
  String get search => 'Search by name, barcode, Lot or Serial';

  @override
  String get allMaterials => 'All Materials';

  @override
  String get availableMaterials => 'Available Materials';

  @override
  String get expiredMaterials => 'Expired or Empty Materials';

  @override
  String get unusedMaterials => 'Unused Materials';

  @override
  String get archivedMaterials => 'Archived Materials';

  @override
  String get showAll => 'Show All Materials';

  @override
  String get addMaterial => 'Add Material';

  @override
  String get editMaterial => 'Edit Material';

  @override
  String get deleteMaterial => 'Archive Material';

  @override
  String get restoreMaterial => 'Restore Material';

  @override
  String get recordUsage => 'Record Usage';

  @override
  String get editUsage => 'Edit Usage';

  @override
  String get name => 'Material Name';

  @override
  String get type => 'Material Type';

  @override
  String get internalNo => 'Internal Number';

  @override
  String get barcode => 'Barcode';

  @override
  String get barcodeFormat => 'Barcode Format';

  @override
  String get gtin => 'GTIN';

  @override
  String get lot => 'Lot Number';

  @override
  String get serial => 'Serial Number';

  @override
  String get catalog => 'Catalog Number';

  @override
  String get department => 'Department';

  @override
  String get device => 'Device';

  @override
  String get storage => 'Storage Location';

  @override
  String get manufacturer => 'Manufacturer';

  @override
  String get originalQty => 'Original Quantity';

  @override
  String get usedQty => 'Used Quantity';

  @override
  String get remainingQty => 'Remaining Quantity';

  @override
  String get unit => 'Unit';

  @override
  String get minStock => 'Minimum Stock';

  @override
  String get receiptDate => 'Receipt Date';

  @override
  String get expiryDate => 'Manufacturer Expiry';

  @override
  String get openDate => 'Open Date';

  @override
  String get afterOpenExpiry => 'After-open Expiry';

  @override
  String get status => 'Status';

  @override
  String get approved => 'Approved';

  @override
  String get notApproved => 'Not Approved';

  @override
  String get blocked => 'Blocked';

  @override
  String get notes => 'Notes';

  @override
  String get saved => 'Data saved';

  @override
  String get deleted => 'Material archived';

  @override
  String get restored => 'Material restored';

  @override
  String get reason => 'Operation Reason';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'Confirm';

  @override
  String get scanHint =>
      'Place the barcode inside the frame and hold the phone steady';

  @override
  String get manualEntry => 'Enter Barcode Manually';

  @override
  String get flash => 'Flash';

  @override
  String get gallery => 'Select Image';

  @override
  String get retry => 'Restart Scanner';

  @override
  String get scanSuccess => 'Barcode read successfully';

  @override
  String get scanFailedManual => 'Unable to scan. Enter the number manually';

  @override
  String get details => 'Material Details';

  @override
  String get usageHistory => 'Usage History';

  @override
  String get noMaterials => 'No materials match the selected options';

  @override
  String get active => 'Active';

  @override
  String get archived => 'Archived';

  @override
  String get role => 'Role';

  @override
  String get superAdmin => 'Super Administrator';

  @override
  String get normalUser => 'Normal User';

  @override
  String get addUser => 'Add User';

  @override
  String get editUser => 'Edit User';

  @override
  String get fullName => 'Full Name';

  @override
  String get employeeNo => 'Employee Number';

  @override
  String get accountStatus => 'Account Status';

  @override
  String get changePassword => 'Change Password';

  @override
  String get cannotDisableLastAdmin =>
      'The last active super administrator cannot be disabled';

  @override
  String get quantity => 'Quantity';

  @override
  String get usageReason => 'Usage or Edit Reason';

  @override
  String get invalidQuantity =>
      'Check the entered quantity and remaining balance';

  @override
  String get refresh => 'Refresh';

  @override
  String get lastRead => 'Last Scanned Value';

  @override
  String get adminOnly =>
      'This operation is restricted to the super administrator';

  @override
  String get approve => 'Approve Material';

  @override
  String get unapprove => 'Cancel Approval';

  @override
  String get block => 'Block Material';

  @override
  String get unblock => 'Unblock Material';

  @override
  String get exportReport => 'Export Report';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get exportExcel => 'Export Excel';

  @override
  String get importExcel => 'Import Users from Excel';

  @override
  String get excelTemplate => 'Download Excel Template';

  @override
  String get settings => 'Settings';

  @override
  String get close => 'Close';

  @override
  String get operationDone => 'Operation completed successfully';

  @override
  String get enterRequired => 'Complete all required fields';

  @override
  String get rawBarcode => 'Raw Barcode Value';

  @override
  String get registeredBy => 'Registered By';

  @override
  String get lastUsedBy => 'Last User';

  @override
  String get lastUsedAt => 'Last Usage';

  @override
  String get createdAt => 'Created At';

  @override
  String get oldValue => 'Old Value';

  @override
  String get newValue => 'New Value';

  @override
  String get performedBy => 'Performed By';

  @override
  String get action => 'Action';
}
