import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'SmartChem Track'**
  String get appTitle;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار 5.0.0'**
  String get version;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @username.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get username;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @invalidLogin.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الدخول غير صحيحة أو الحساب موقوف'**
  String get invalidLogin;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'لغة التطبيق'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @welcome.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا'**
  String get welcome;

  /// No description provided for @totalMaterials.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المواد'**
  String get totalMaterials;

  /// No description provided for @available.
  ///
  /// In ar, this message translates to:
  /// **'متوفرة'**
  String get available;

  /// No description provided for @expiredOrEmpty.
  ///
  /// In ar, this message translates to:
  /// **'منتهية أو نافدة'**
  String get expiredOrEmpty;

  /// No description provided for @unused.
  ///
  /// In ar, this message translates to:
  /// **'غير مستخدمة'**
  String get unused;

  /// No description provided for @scanMaterial.
  ///
  /// In ar, this message translates to:
  /// **'مسح باركود المادة'**
  String get scanMaterial;

  /// No description provided for @inventory.
  ///
  /// In ar, this message translates to:
  /// **'المخزون وسجل المواد'**
  String get inventory;

  /// No description provided for @userManagement.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المستخدمين'**
  String get userManagement;

  /// No description provided for @auditTrail.
  ///
  /// In ar, this message translates to:
  /// **'سجل العمليات'**
  String get auditTrail;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'البحث بالاسم أو الباركود أو Lot أو Serial'**
  String get search;

  /// No description provided for @allMaterials.
  ///
  /// In ar, this message translates to:
  /// **'جميع المواد'**
  String get allMaterials;

  /// No description provided for @availableMaterials.
  ///
  /// In ar, this message translates to:
  /// **'المواد المتوفرة'**
  String get availableMaterials;

  /// No description provided for @expiredMaterials.
  ///
  /// In ar, this message translates to:
  /// **'المواد المنتهية أو النافدة'**
  String get expiredMaterials;

  /// No description provided for @unusedMaterials.
  ///
  /// In ar, this message translates to:
  /// **'المواد غير المستخدمة'**
  String get unusedMaterials;

  /// No description provided for @archivedMaterials.
  ///
  /// In ar, this message translates to:
  /// **'المواد المؤرشفة'**
  String get archivedMaterials;

  /// No description provided for @showAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض جميع المواد'**
  String get showAll;

  /// No description provided for @addMaterial.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مادة'**
  String get addMaterial;

  /// No description provided for @editMaterial.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المادة'**
  String get editMaterial;

  /// No description provided for @deleteMaterial.
  ///
  /// In ar, this message translates to:
  /// **'حذف المادة'**
  String get deleteMaterial;

  /// No description provided for @restoreMaterial.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع المادة'**
  String get restoreMaterial;

  /// No description provided for @recordUsage.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل استخدام'**
  String get recordUsage;

  /// No description provided for @editUsage.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الاستخدام'**
  String get editUsage;

  /// No description provided for @name.
  ///
  /// In ar, this message translates to:
  /// **'اسم المادة'**
  String get name;

  /// No description provided for @type.
  ///
  /// In ar, this message translates to:
  /// **'نوع المادة'**
  String get type;

  /// No description provided for @internalNo.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الداخلي'**
  String get internalNo;

  /// No description provided for @barcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get barcode;

  /// No description provided for @barcodeFormat.
  ///
  /// In ar, this message translates to:
  /// **'صيغة الباركود'**
  String get barcodeFormat;

  /// No description provided for @gtin.
  ///
  /// In ar, this message translates to:
  /// **'GTIN'**
  String get gtin;

  /// No description provided for @lot.
  ///
  /// In ar, this message translates to:
  /// **'رقم التشغيلة Lot'**
  String get lot;

  /// No description provided for @serial.
  ///
  /// In ar, this message translates to:
  /// **'الرقم التسلسلي'**
  String get serial;

  /// No description provided for @catalog.
  ///
  /// In ar, this message translates to:
  /// **'رقم الكتالوج'**
  String get catalog;

  /// No description provided for @department.
  ///
  /// In ar, this message translates to:
  /// **'القسم'**
  String get department;

  /// No description provided for @device.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز'**
  String get device;

  /// No description provided for @storage.
  ///
  /// In ar, this message translates to:
  /// **'موقع التخزين'**
  String get storage;

  /// No description provided for @manufacturer.
  ///
  /// In ar, this message translates to:
  /// **'الشركة المصنعة'**
  String get manufacturer;

  /// No description provided for @originalQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الأصلية'**
  String get originalQty;

  /// No description provided for @usedQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المستخدمة'**
  String get usedQty;

  /// No description provided for @remainingQty.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المتبقية'**
  String get remainingQty;

  /// No description provided for @unit.
  ///
  /// In ar, this message translates to:
  /// **'وحدة القياس'**
  String get unit;

  /// No description provided for @minStock.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى للمخزون'**
  String get minStock;

  /// No description provided for @receiptDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الاستلام'**
  String get receiptDate;

  /// No description provided for @expiryDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ انتهاء الشركة'**
  String get expiryDate;

  /// No description provided for @openDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الفتح'**
  String get openDate;

  /// No description provided for @afterOpenExpiry.
  ///
  /// In ar, this message translates to:
  /// **'الانتهاء بعد الفتح'**
  String get afterOpenExpiry;

  /// No description provided for @status.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get status;

  /// No description provided for @approved.
  ///
  /// In ar, this message translates to:
  /// **'معتمدة'**
  String get approved;

  /// No description provided for @notApproved.
  ///
  /// In ar, this message translates to:
  /// **'غير معتمدة'**
  String get notApproved;

  /// No description provided for @blocked.
  ///
  /// In ar, this message translates to:
  /// **'محظورة'**
  String get blocked;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظات'**
  String get notes;

  /// No description provided for @saved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ البيانات'**
  String get saved;

  /// No description provided for @deleted.
  ///
  /// In ar, this message translates to:
  /// **'تمت أرشفة المادة'**
  String get deleted;

  /// No description provided for @restored.
  ///
  /// In ar, this message translates to:
  /// **'تم استرجاع المادة'**
  String get restored;

  /// No description provided for @reason.
  ///
  /// In ar, this message translates to:
  /// **'سبب العملية'**
  String get reason;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @scanHint.
  ///
  /// In ar, this message translates to:
  /// **'ضع الباركود داخل الإطار وثبّت الهاتف للحظات'**
  String get scanHint;

  /// No description provided for @manualEntry.
  ///
  /// In ar, this message translates to:
  /// **'إدخال الباركود يدويًا'**
  String get manualEntry;

  /// No description provided for @flash.
  ///
  /// In ar, this message translates to:
  /// **'الفلاش'**
  String get flash;

  /// No description provided for @gallery.
  ///
  /// In ar, this message translates to:
  /// **'اختيار صورة'**
  String get gallery;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تشغيل المسح'**
  String get retry;

  /// No description provided for @scanSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تمت قراءة الباركود بنجاح'**
  String get scanSuccess;

  /// No description provided for @scanFailedManual.
  ///
  /// In ar, this message translates to:
  /// **'تعذرت القراءة، أدخل الرقم يدويًا'**
  String get scanFailedManual;

  /// No description provided for @details.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المادة'**
  String get details;

  /// No description provided for @usageHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الاستخدام'**
  String get usageHistory;

  /// No description provided for @noMaterials.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواد مطابقة للخيارات المحددة'**
  String get noMaterials;

  /// No description provided for @active.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get active;

  /// No description provided for @archived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get archived;

  /// No description provided for @role.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get role;

  /// No description provided for @superAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم رئيسي'**
  String get superAdmin;

  /// No description provided for @normalUser.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم عادي'**
  String get normalUser;

  /// No description provided for @addUser.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مستخدم'**
  String get addUser;

  /// No description provided for @editUser.
  ///
  /// In ar, this message translates to:
  /// **'تعديل مستخدم'**
  String get editUser;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الشخص'**
  String get fullName;

  /// No description provided for @employeeNo.
  ///
  /// In ar, this message translates to:
  /// **'الرقم الوظيفي'**
  String get employeeNo;

  /// No description provided for @accountStatus.
  ///
  /// In ar, this message translates to:
  /// **'حالة الحساب'**
  String get accountStatus;

  /// No description provided for @changePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get changePassword;

  /// No description provided for @cannotDisableLastAdmin.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إيقاف أو حذف آخر مستخدم رئيسي'**
  String get cannotDisableLastAdmin;

  /// No description provided for @quantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantity;

  /// No description provided for @usageReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب الاستخدام أو التعديل'**
  String get usageReason;

  /// No description provided for @invalidQuantity.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من الكمية المدخلة والرصيد المتبقي'**
  String get invalidQuantity;

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get refresh;

  /// No description provided for @lastRead.
  ///
  /// In ar, this message translates to:
  /// **'آخر قيمة تمت قراءتها'**
  String get lastRead;

  /// No description provided for @adminOnly.
  ///
  /// In ar, this message translates to:
  /// **'هذه العملية متاحة للمستخدم الرئيسي فقط'**
  String get adminOnly;

  /// No description provided for @approve.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد المادة'**
  String get approve;

  /// No description provided for @unapprove.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الاعتماد'**
  String get unapprove;

  /// No description provided for @block.
  ///
  /// In ar, this message translates to:
  /// **'حظر المادة'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحظر'**
  String get unblock;

  /// No description provided for @exportReport.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل التقرير'**
  String get exportReport;

  /// No description provided for @exportPdf.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل PDF'**
  String get exportPdf;

  /// No description provided for @exportExcel.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل Excel'**
  String get exportExcel;

  /// No description provided for @importExcel.
  ///
  /// In ar, this message translates to:
  /// **'استيراد المستخدمين من Excel'**
  String get importExcel;

  /// No description provided for @excelTemplate.
  ///
  /// In ar, this message translates to:
  /// **'تنزيل نموذج Excel'**
  String get excelTemplate;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @operationDone.
  ///
  /// In ar, this message translates to:
  /// **'تم تنفيذ العملية بنجاح'**
  String get operationDone;

  /// No description provided for @enterRequired.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الحقول المطلوبة'**
  String get enterRequired;

  /// No description provided for @rawBarcode.
  ///
  /// In ar, this message translates to:
  /// **'القيمة الأصلية للباركود'**
  String get rawBarcode;

  /// No description provided for @registeredBy.
  ///
  /// In ar, this message translates to:
  /// **'سجلها'**
  String get registeredBy;

  /// No description provided for @lastUsedBy.
  ///
  /// In ar, this message translates to:
  /// **'آخر مستخدم'**
  String get lastUsedBy;

  /// No description provided for @lastUsedAt.
  ///
  /// In ar, this message translates to:
  /// **'آخر استخدام'**
  String get lastUsedAt;

  /// No description provided for @createdAt.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإنشاء'**
  String get createdAt;

  /// No description provided for @oldValue.
  ///
  /// In ar, this message translates to:
  /// **'القيمة القديمة'**
  String get oldValue;

  /// No description provided for @newValue.
  ///
  /// In ar, this message translates to:
  /// **'القيمة الجديدة'**
  String get newValue;

  /// No description provided for @performedBy.
  ///
  /// In ar, this message translates to:
  /// **'نفذها'**
  String get performedBy;

  /// No description provided for @action.
  ///
  /// In ar, this message translates to:
  /// **'العملية'**
  String get action;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
