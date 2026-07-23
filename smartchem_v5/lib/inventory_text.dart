import 'package:flutter/widgets.dart';

class InventoryText {
  InventoryText(BuildContext context)
    : isArabic = Localizations.localeOf(context).languageCode == 'ar';

  final bool isArabic;

  String value(String ar, String en) => isArabic ? ar : en;

  String get hierarchy => value(
    'المنتجات والدفعات والكراتين والعلب',
    'Products, LOTs, cartons and units',
  );
  String get products => value('المنتجات', 'Products');
  String get product => value('المنتج', 'Product');
  String get lots => value('الدفعات LOT', 'LOTs');
  String get lot => value('رقم LOT', 'LOT');
  String get cartons => value('الكراتين', 'Cartons');
  String get carton => value('الكرتون', 'Carton');
  String get units => value('العلب', 'Units');
  String get unit => value('العلبة', 'Unit');
  String get addProduct => value('إضافة منتج', 'Add product');
  String get addLot => value('إضافة LOT', 'Add LOT');
  String get addCarton => value('إضافة كرتون وعلبه', 'Add carton and units');
  String get editProduct => value('تعديل المنتج', 'Edit product');
  String get sku => value('رمز المنتج', 'Product SKU');
  String get name => value('الاسم', 'Name');
  String get type => value('النوع', 'Type');
  String get gtin => 'GTIN';
  String get catalog => value('رقم الكتالوج', 'Catalog number');
  String get manufacturer => value('الشركة المصنعة', 'Manufacturer');
  String get department => value('القسم', 'Department');
  String get storage => value('موقع التخزين', 'Storage location');
  String get measureUnit => value('وحدة القياس', 'Measure unit');
  String get afterOpenDays =>
      value('مدة الثبات بعد الفتح (أيام)', 'Stability after opening (days)');
  String get stabilityOption =>
      value('تفعيل مدة وفترة الثبات', 'Enable stability period');
  String get stabilityDuration => value('مدة الثبات', 'Stability duration');
  String get stabilityPeriod => value('فترة الثبات', 'Stability period');
  String get hour => value('ساعة', 'Hour');
  String get day => value('يوم', 'Day');
  String get week => value('أسبوع', 'Week');
  String get month => value('شهر', 'Month');
  String get intakeTitle =>
      value('تسجيل الكرتون من الباركود', 'Register carton from barcode');
  String get automaticData =>
      value('بيانات مستخرجة تلقائيًا', 'Automatically captured data');
  String get requiredData =>
      value('بيانات يجب تسجيلها', 'Required registration data');
  String get internalNumber => value('الرقم الداخلي', 'Internal number');
  String get rawBarcode =>
      value('القيمة الأصلية للباركود', 'Original barcode value');
  String get receivedAt => value('تاريخ الاستلام', 'Receipt date');
  String get manufacturerExpiry =>
      value('تاريخ انتهاء الشركة', 'Manufacturer expiry');
  String get materialName => value('اسم المادة', 'Material name');
  String get abbottListNo => 'Abbott List No';
  String get mohCode => 'MOH Code';
  String get device => value('الجهاز', 'Device');
  String get other => value('أخرى', 'Other');
  String get unitsPerCarton =>
      value('عدد العلب في الكرتون الواحد', 'Units in one carton');
  String get importCatalog =>
      value('استيراد قائمة المواد من Excel', 'Import material list from Excel');
  String get catalogEmpty => value(
    'قائمة المواد فارغة. استورد ملف Excel الذي يحتوي على اسم المادة وAbbott List No وMOH Code.',
    'The material list is empty. Import an Excel file containing material name, Abbott List No and MOH Code.',
  );
  String get importedRows =>
      value('تم استيراد عدد المواد', 'Imported material rows');
  String get previousUnitWarning => value(
    'لا يمكن استخدام هذه العلبة قبل إنهاء العلبة السابقة',
    'This unit cannot be used before the previous unit is finished',
  );
  String get expiredUnitWarning => value(
    'انتهت صلاحية العلبة بعد الفتح ولا يمكن استخدامها.',
    'The unit has expired after opening and cannot be used.',
  );
  String get automaticallyOpened => value(
    'يسجل تاريخ الفتح تلقائيًا عند أول استخدام.',
    'The opening time is recorded automatically on first use.',
  );
  String get disabled => value('غير مفعلة', 'Disabled');
  String get expiry => value('تاريخ الانتهاء', 'Expiry date');
  String get received => value('تاريخ الاستلام', 'Received date');
  String get cartonCode => value('رمز الكرتون', 'Carton code');
  String get unitCount => value('عدد العلب', 'Unit count');
  String get quantityPerUnit => value('الكمية في العلبة', 'Quantity per unit');
  String get openedAt => value('تاريخ الفتح', 'Opened at');
  String get afterOpenExpiry =>
      value('انتهاء الثبات بعد الفتح', 'After-open expiry');
  String get effectiveExpiry => value('الانتهاء الفعلي', 'Effective expiry');
  String get remaining => value('المتبقي', 'Remaining');
  String get openUnit => value('فتح العلبة الآن', 'Open unit now');
  String get recordUsage => value('تسجيل استخدام', 'Record usage');
  String get printCarton => value('طباعة ملصق الكرتون', 'Print carton label');
  String get printUnits => value('طباعة ملصقات العلب', 'Print unit labels');
  String get printUnit => value('طباعة ملصق العلبة', 'Print unit label');
  String get copies => value('عدد النسخ', 'Copies');
  String get save => value('حفظ', 'Save');
  String get cancel => value('إلغاء', 'Cancel');
  String get required => value('هذا الحقل مطلوب', 'This field is required');
  String get invalidNumber =>
      value('أدخل رقمًا صحيحًا', 'Enter a valid number');
  String get noData => value('لا توجد بيانات بعد', 'No data yet');
  String get migrated => value(
    'تم ترحيل المخزون السابق دون حذف بياناته',
    'Legacy inventory was migrated without deleting data',
  );
  String get sealed => value('مغلقة', 'Sealed');
  String get opened => value('مفتوحة', 'Opened');
  String get empty => value('فارغة', 'Empty');
  String get expired => value('منتهية', 'Expired');
  String get usageQuantity => value('الكمية المستخدمة', 'Used quantity');
  String get reason => value('السبب / الملاحظة', 'Reason / note');
  String get success => value('تم الحفظ بنجاح', 'Saved successfully');
  String get labelQueued => value(
    'تم إنشاء الملصق وإرساله للطباعة',
    'Label generated and sent to printing',
  );
  String get scanUnit => value('مسح علبة', 'Scan unit');
}
