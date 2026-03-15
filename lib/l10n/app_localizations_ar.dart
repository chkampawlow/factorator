// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get cancel => 'إلغاء';

  @override
  String get currency => 'العملة';

  @override
  String get selectCurrency => 'اختر العملة';

  @override
  String get language => 'اللغة';

  @override
  String get selectLanguage => 'اختر اللغة';

  @override
  String get appColor => 'لون التطبيق';

  @override
  String get toggleTheme => 'تبديل المظهر';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get fiscalId => 'المعرّف الجبائي';

  @override
  String get noUserData => 'لا توجد بيانات مستخدم';

  @override
  String get logoutQuestion => 'هل تريد تسجيل الخروج؟';

  @override
  String currencyChanged(String value) {
    return 'تم تغيير العملة إلى $value';
  }

  @override
  String languageChanged(String value) {
    return 'تم تغيير اللغة إلى $value';
  }

  @override
  String get clientUpdateApiNotAddedYet => 'واجهة تحديث العميل غير متوفرة بعد';

  @override
  String get clientAddedSuccessfully => 'تمت إضافة العميل بنجاح';

  @override
  String clientAddedSuccessfullyWithId(String id) {
    return 'تمت إضافة العميل بنجاح بالمعرف $id';
  }

  @override
  String get saveFailed => 'فشل الحفظ';

  @override
  String get fiscalIdMf => 'المعرّف الجبائي (MF)';

  @override
  String get cin => 'رقم الهوية';

  @override
  String get editCustomer => 'تعديل العميل';

  @override
  String get addCustomer => 'إضافة عميل';

  @override
  String get companyName => 'اسم الشركة';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get requiredField => 'حقل مطلوب';

  @override
  String get mfRequired => 'المعرّف الجبائي مطلوب';

  @override
  String get cinRequired => 'رقم الهوية مطلوب';

  @override
  String get cinTooShort => 'رقم الهوية قصير جداً';

  @override
  String get emailOptional => 'البريد الإلكتروني (اختياري)';

  @override
  String get phoneOptional => 'الهاتف (اختياري)';

  @override
  String get addressOptional => 'العنوان (اختياري)';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get saveCustomer => 'حفظ العميل';

  @override
  String get newInvoice => 'فاتورة جديدة';

  @override
  String get saving => 'جارٍ الحفظ...';

  @override
  String get createInvoice => 'إنشاء الفاتورة';

  @override
  String get client => 'العميل';

  @override
  String get chooseClientOrAddNew => 'اختر عميلًا أو أضف واحدًا جديدًا';

  @override
  String get dueDate => 'تاريخ الاستحقاق';

  @override
  String get nextStep => 'الخطوة التالية';

  @override
  String issueDateAutoToday(String date) {
    return 'سيتم ضبط تاريخ الفاتورة تلقائيًا على تاريخ اليوم ($date). بعد إنشاء الفاتورة، سيتم توجيهك إلى شاشة تفاصيل الفاتورة حيث يمكنك إضافة عناصر الفاتورة.';
  }

  @override
  String get clientSelectionFailed => 'فشل اختيار العميل';

  @override
  String get pleaseChooseClient => 'يرجى اختيار عميل.';

  @override
  String get chooseClient => 'اختر العميل';

  @override
  String get addNewClient => 'إضافة عميل جديد';

  @override
  String get loadFailed => 'فشل التحميل';

  @override
  String get invalidNumber => 'رقم غير صالح';

  @override
  String get priceAndTvaMustBeValidNumbers => 'يجب أن يكون السعر ونسبة TVA أرقامًا صالحة.';

  @override
  String get invalidProductId => 'معرّف المنتج غير صالح';

  @override
  String get productUpdatedSuccessfully => 'تم تحديث المنتج بنجاح';

  @override
  String get productSavedSuccessfully => 'تم حفظ المنتج بنجاح';

  @override
  String get editProduct => 'تعديل المنتج';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get saveProduct => 'حفظ المنتج';

  @override
  String get updateProductDetails => 'تحديث تفاصيل المنتج';

  @override
  String get createNewProductOrService => 'إنشاء منتج أو خدمة جديدة';

  @override
  String get codeOptional => 'الرمز (اختياري)';

  @override
  String get productCodeExample => 'مثال: PRD-001';

  @override
  String get productServiceName => 'اسم المنتج / الخدمة';

  @override
  String get productServiceNameExample => 'مثال: تصميم ويب، استشارة...';

  @override
  String get price => 'السعر';

  @override
  String get priceExample => 'مثال: 120 أو 120,50';

  @override
  String get tvaPercent => 'نسبة TVA %';

  @override
  String get tvaExample => 'مثال: 19';

  @override
  String get unitOptional => 'الوحدة (اختيارية)';

  @override
  String get unitExample => 'ساعة / قطعة / كغ...';

  @override
  String get failedToLoadCustomers => 'فشل تحميل العملاء';

  @override
  String get mfLabel => 'المعرف الجبائي';

  @override
  String get missingClientId => 'معرّف العميل مفقود';

  @override
  String get invalidClientId => 'معرّف العميل غير صالح';

  @override
  String get deleteCustomerQuestion => 'حذف العميل؟';

  @override
  String areYouSureDeleteCustomer(String name) {
    return 'هل أنت متأكد أنك تريد حذف \"$name\"؟';
  }

  @override
  String get delete => 'حذف';

  @override
  String get customerDeletedSuccessfully => 'تم حذف العميل بنجاح';

  @override
  String get deleteFailed => 'فشل الحذف';

  @override
  String get unnamedCustomer => 'عميل بدون اسم';

  @override
  String get customers => 'العملاء';

  @override
  String get refresh => 'تحديث';

  @override
  String get add => 'إضافة';

  @override
  String get searchNameMfCin => 'بحث (الاسم / MF / CIN)...';

  @override
  String get allCustomers => 'كل العملاء';

  @override
  String get noCustomersYet => 'لا يوجد عملاء بعد';

  @override
  String get edit => 'تعديل';
}
