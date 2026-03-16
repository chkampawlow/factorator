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
  String get fiscalId => 'المعرف الجبائي';

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
  String get dashboard => 'لوحة التحكم';

  @override
  String get quickActions => 'الإجراءات السريعة';

  @override
  String get advanceInvoice => 'فاتورة مسبقة';

  @override
  String get advanceInvoiceComingSoon => 'الفاتورة المسبقة: قريباً';

  @override
  String get recentTransactions => 'المعاملات الأخيرة';

  @override
  String get all => 'الكل';

  @override
  String get noInvoicesYet => 'لا توجد فواتير بعد.';

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

  @override
  String get invoice => 'الفاتورة';

  @override
  String get status => 'الحالة';

  @override
  String get issue => 'الإصدار';

  @override
  String get due => 'الاستحقاق';

  @override
  String get fill => 'تعبئة';

  @override
  String get previewPdf => 'معاينة PDF';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get error => 'خطأ';

  @override
  String get invoiceNotFound => 'الفاتورة غير موجودة.';

  @override
  String get addAtLeastOneItemBeforePreviewPdf => 'أضف عنصرًا واحدًا على الأقل قبل معاينة ملف PDF.';

  @override
  String get qtyMustBeGreaterThanZero => 'يجب أن تكون الكمية أكبر من 0';

  @override
  String get itemAdded => 'تمت إضافة العنصر';

  @override
  String get itemDeleted => 'تم حذف العنصر';

  @override
  String get itemUpdated => 'تم تحديث العنصر';

  @override
  String get deleteItem => 'حذف العنصر';

  @override
  String get removeThisItemFromInvoice => 'إزالة هذا العنصر من الفاتورة؟';

  @override
  String get editItem => 'تعديل العنصر';

  @override
  String get qty => 'الكمية';

  @override
  String get discountPercent => 'الخصم (%)';

  @override
  String get save => 'حفظ';

  @override
  String get addItem => 'إضافة عنصر';

  @override
  String get product => 'المنتج';

  @override
  String get priceOverride => 'استبدال السعر';

  @override
  String get addToInvoice => 'إضافة إلى الفاتورة';

  @override
  String get noItemsYet => 'لا توجد عناصر بعد.';

  @override
  String get invoices => 'الفواتير';

  @override
  String get overdue => 'متأخرة';

  @override
  String get code => 'الرمز';

  @override
  String get type => 'النوع';

  @override
  String get doc => 'الوثيقة';

  @override
  String get issued => 'أُصدرت في';

  @override
  String get dueToday => 'الاستحقاق اليوم';

  @override
  String dueInDays(String days, String suffix) {
    return 'الاستحقاق خلال $days يوم$suffix';
  }

  @override
  String overdueByDays(String days, String suffix) {
    return 'متأخرة بمقدار $days يوم$suffix';
  }

  @override
  String get createYourFirstInvoiceToSeeItHere => 'أنشئ فاتورتك الأولى لتظهر هنا.';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get loginToManageApp => 'سجّل الدخول لإدارة العملاء والمنتجات والفواتير.';

  @override
  String get emailAddress => 'عنوان البريد الإلكتروني';

  @override
  String get emailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get enterValidEmail => 'أدخل بريداً إلكترونياً صالحاً';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';

  @override
  String get minimum6Characters => 'الحد الأدنى 6 أحرف';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟ ';

  @override
  String get createOne => 'أنشئ واحداً';

  @override
  String get loginSuccess => 'تم تسجيل الدخول بنجاح';

  @override
  String welcomeUser(String name) {
    return 'مرحباً $name';
  }

  @override
  String get productsServices => 'المنتجات / الخدمات';

  @override
  String get searchProductsHint => 'بحث (الاسم / الرمز / الوحدة / TVA)...';

  @override
  String get noProductsYet => 'لا توجد منتجات بعد';

  @override
  String get deleteProductQuestion => 'حذف المنتج؟';

  @override
  String areYouSureDeleteProduct(String name) {
    return 'هل أنت متأكد أنك تريد حذف \"$name\"؟';
  }

  @override
  String get productDeleted => 'تم حذف المنتج ✅';

  @override
  String get unnamedProduct => 'منتج بدون اسم';

  @override
  String get unit => 'الوحدة';

  @override
  String get firstNameRequired => 'الاسم الأول مطلوب';

  @override
  String get lastNameRequired => 'اسم العائلة مطلوب';

  @override
  String get fiscalIdRequired => 'المعرف الجبائي مطلوب';

  @override
  String get fiscalIdMustMatch => 'يجب أن يطابق المعرف الجبائي 1234567ABC123';

  @override
  String get passwordMinLength => 'يجب أن تحتوي كلمة المرور على 6 أحرف على الأقل';

  @override
  String get pleaseConfirmPassword => 'يرجى تأكيد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get accountCreatedSuccessfully => 'تم إنشاء الحساب بنجاح';

  @override
  String get whoAreYou => 'من أنت؟';

  @override
  String get startWithPersonalInformation => 'ابدأ بمعلوماتك الشخصية.';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get lastName => 'اسم العائلة';

  @override
  String get companyDetails => 'تفاصيل الشركة';

  @override
  String get addOrganizationAndFiscalInfo => 'أضف مؤسستك ومعلوماتك الجبائية.';

  @override
  String get organizationName => 'اسم الشركة';

  @override
  String get fiscalIdRequiredLabel => 'المعرف الجبائي*';

  @override
  String get fiscalIdFormat => 'الصيغة: 1234567ABC123';

  @override
  String get contactInformation => 'معلومات الاتصال';

  @override
  String get howCanWeReachYou => 'كيف يمكننا التواصل معك؟';

  @override
  String get emailAddressLabel => 'عنوان البريد الإلكتروني';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get secureYourAccount => 'أمّن حسابك';

  @override
  String get chooseStrongPassword => 'اختر كلمة مرور قوية.';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get reviewAndCreate => 'مراجعة وإنشاء';

  @override
  String get reviewBeforeCreate => 'تأكد من صحة كل شيء قبل إنشاء الحساب.';

  @override
  String get organization => 'المؤسسة';

  @override
  String get fiscalIdLabel => 'المعرف الجبائي';

  @override
  String get phone => 'الهاتف';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get back => 'رجوع';

  @override
  String get continueText => 'متابعة';

  @override
  String get invalidFiscalId => 'المعرف الجبائي غير صالح';

  @override
  String get phoneNumberRequired => 'رقم الهاتف مطلوب';

  @override
  String get phoneNumberInvalid => 'رقم الهاتف غير صالح';

  @override
  String get clients => 'العملاء';

  @override
  String get items => 'العناصر';

  @override
  String get searchProduct => 'ابحث عن منتج';

  @override
  String get noProductsFound => 'لم يتم العثور على منتجات';

  @override
  String get selectProduct => 'اختر منتجًا';

  @override
  String get companyInformation => 'معلومات الشركة';

  @override
  String get fax => 'فاكس';

  @override
  String get address => 'العنوان';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get profileImageUpdated => 'تم تحديث صورة الملف الشخصي';

  @override
  String get tapImageToChangePhoto => 'اضغط على الصورة لتغييرها';

  @override
  String get region => 'المنطقة';

  @override
  String get name => 'Name';

  @override
  String get identifier => 'Identifier';

  @override
  String get notes => 'Notes';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get total => 'Total';
}
