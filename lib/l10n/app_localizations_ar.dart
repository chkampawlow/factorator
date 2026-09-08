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
  String get loadFailed => 'فشل في التحميل';

  @override
  String get serverUnavailable => 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';

  @override
  String get requestTimedOut => 'استغرق الخادم وقتًا طويلًا للرد. حاول مرة أخرى.';

  @override
  String get accountingServerUpdateRequired => 'وحدة المراجعة المحاسبية غير مثبتة على الخادم بعد. انشر أحدث إصدار من الواجهة الخلفية ثم حاول مرة أخرى.';

  @override
  String get captureCenterTitle => 'الالتقاط';

  @override
  String get captureCenterSubtitle => 'امسح مستندًا أو اختر ملفات PDF وصورًا أو ابحث عن منتج بالرمز الشريطي.';

  @override
  String get captureTakePhoto => 'التقاط صورة';

  @override
  String get captureChooseFiles => 'اختيار PDF أو صور';

  @override
  String get captureScanBarcode => 'مسح الرمز الشريطي للمنتج';

  @override
  String get extractorTitle => 'مستخرج المستندات';

  @override
  String get extractorReady => 'اختر حتى 10 ملفات ثم شغّل الاستخراج.';

  @override
  String extractorSelectedFiles(int count) {
    return 'تم اختيار $count ملف';
  }

  @override
  String get extractorRun => 'تشغيل الاستخراج';

  @override
  String extractorUploading(int percent) {
    return 'جارٍ الرفع $percent%';
  }

  @override
  String get extractorProcessing => 'اكتمل الرفع. جارٍ استخراج حقول المستند…';

  @override
  String get extractorReviewRequired => 'لا يقوم الاستخراج أبدًا باعتماد مستند مالي. راجع كل حقل قبل إنشاء المسودة.';

  @override
  String extractorBatchSummary(int processed, int requested) {
    return 'تمت معالجة $processed من $requested ملف';
  }

  @override
  String get extractorSuccessRate => 'نسبة النجاح';

  @override
  String get extractorPages => 'الصفحات';

  @override
  String get extractorFailed => 'فشل الاستخراج';

  @override
  String get extractorReview => 'مراجعة الحقول';

  @override
  String get extractorReviewTitle => 'مراجعة بشرية';

  @override
  String get extractorReviewSubtitle => 'صحح القيم المستخرجة واختر نوع المستند المقصود.';

  @override
  String get extractorDocumentType => 'نوع المستند';

  @override
  String get extractorExpense => 'وصل مصروف';

  @override
  String get extractorSupplierInvoice => 'فاتورة مورد';

  @override
  String get extractorSupplierDelivery => 'وثيقة تسليم مورد';

  @override
  String get extractorPurchaseOrder => 'طلب شراء';

  @override
  String get extractorWarnings => 'تحذيرات المراجعة';

  @override
  String get extractorLineItems => 'البنود المستخرجة';

  @override
  String get extractorNoLineItems => 'لم يتم اكتشاف أي بنود.';

  @override
  String extractorConfidence(int percent) {
    return 'نسبة الثقة: $percent%';
  }

  @override
  String get extractorConfirmReviewed => 'راجعت القيم المستخرجة وصححتها.';

  @override
  String get extractorCreatePendingExpense => 'إعداد مصروف قيد الانتظار';

  @override
  String get extractorDraftNotice => 'سيتم فتح نموذج معبأ مسبقًا. لن يتم حفظ شيء قبل مراجعته وإرساله، ويبدأ المصروف الجديد دائمًا بحالة قيد الانتظار.';

  @override
  String get extractorDestinationNeedsWeb => 'تحتاج هذه الوجهة إلى مطابقة معتمدة للمورد والطلب والاستلام والمنتجات والملف الضريبي. أكملها في مساحة الويب حاليًا.';

  @override
  String get extractorPermissionDenied => 'يمكن لدورك التقاط المستندات لكنه لا يستطيع استخدام المستخرج.';

  @override
  String get extractorExpensePermissionDenied => 'لا يسمح دورك بإنشاء ملاحظات المصروفات.';

  @override
  String get extractorServerUpdateRequired => 'المستخرج غير مثبت على الخادم المنشور بعد.';

  @override
  String get extractorRemoveFile => 'إزالة الملف';

  @override
  String get extractorRawText => 'النص الخام المستخرج';

  @override
  String get extractorFileLimits => 'PDF أو PNG أو JPG أو TIFF أو BMP أو WebP · ‏15 م.ب لكل ملف · ‏50 م.ب لكل دفعة';

  @override
  String get extractorNoFilesSelected => 'اختر ملف PDF أو صورة واحدة على الأقل.';

  @override
  String get extractorExtractedData => 'البيانات المستخرجة';

  @override
  String get extractorTaxAmount => 'مبلغ الضريبة';

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
  String get scanInvoiceTitle => 'مسح الفاتورة';

  @override
  String get scanInvoiceSubtitle => 'ضع الفاتورة داخل الإطار. هذه واجهة الكاميرا فقط.';

  @override
  String get scanInvoiceMode => 'فاتورة';

  @override
  String get scanInvoiceAlign => 'قم بمحاذاة الفاتورة داخل الإطار';

  @override
  String get scanInvoiceGuideTitle => 'دليل المسح';

  @override
  String get scanInvoiceGuideLight => 'استخدم إضاءة جيدة وتجنب الظلال على الورقة.';

  @override
  String get scanInvoiceGuideEdges => 'حافظ على ظهور كل زوايا الفاتورة داخل الإطار.';

  @override
  String get scanInvoiceGuideReadable => 'تأكد من أن الإجماليات ومعلومات المورد واضحة.';

  @override
  String get quickActions => 'الإجراءات السريعة';

  @override
  String get advanceInvoice => 'فاتورة مسبقة';

  @override
  String get advanceInvoiceComingSoon => 'الفاتورة المسبقة: قريباً';

  @override
  String get recentTransactions => 'الإحصائيات';

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
  String get searchNameMfCin => 'بحث بالاسم / MF / CIN';

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
  String get overdue => 'متأخر';

  @override
  String get code => 'رمز الدولة';

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
  String get forgotPassword => 'نسيت كلمة المرور';

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
  String get fiscalIdMustMatch => 'يجب أن يطابق المعرف الجبائي 1234567A';

  @override
  String get passwordMinLength => 'يجب أن تحتوي كلمة المرور على 6 أحرف على الأقل';

  @override
  String get pleaseConfirmPassword => 'يرجى تأكيد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get accountCreatedSuccessfully => 'تم إنشاء الحساب بنجاح';

  @override
  String get accountAwaitingApproval => 'تم إنشاء الحساب وهو في انتظار موافقة المسؤول.';

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
  String get fiscalIdFormat => 'الصيغة: 1234567A';

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
  String get name => 'الاسم';

  @override
  String get identifier => 'المعرّف';

  @override
  String get notes => 'ملاحظات';

  @override
  String get note => 'ملاحظة';

  @override
  String get addNote => 'إضافة ملاحظة';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get paymentCash => 'نقدًا';

  @override
  String get paymentCard => 'بطاقة';

  @override
  String get paymentTransfer => 'تحويل بنكي';

  @override
  String get paymentCheck => 'شيك';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get total => 'الإجمالي';

  @override
  String get verifyEmail => 'تحقق من بريدك الإلكتروني';

  @override
  String get verifyEmailDescription => 'يرجى التحقق من بريدك الإلكتروني قبل المتابعة. أدخل الرمز المكوّن من 6 أرقام أو أعد إرسال البريد.';

  @override
  String get verificationCode => 'رمز التحقق';

  @override
  String get verifyNow => 'تحقق الآن';

  @override
  String get resendEmail => 'إعادة إرسال البريد';

  @override
  String resendEmailIn(int seconds) {
    return 'إعادة إرسال البريد خلال $secondsث';
  }

  @override
  String get verificationEmailSent => 'تم إرسال بريد التحقق';

  @override
  String get enterVerificationCode => 'أدخل رمز التحقق';

  @override
  String get emailVerifiedSuccessfully => 'تم التحقق من البريد الإلكتروني بنجاح';

  @override
  String get forgotPasswordDescription => 'أدخل بريدك الإلكتروني وسنرسل لك رمزًا مكوّنًا من 6 أرقام لإعادة تعيين كلمة المرور.';

  @override
  String get sendResetCode => 'إرسال رمز إعادة التعيين';

  @override
  String get resetCodeSent => 'تم إرسال رمز إعادة التعيين';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get resetPasswordDescription => 'أدخل الرمز المكوّن من 6 أرقام وكلمة المرور الجديدة.';

  @override
  String get enterResetCode => 'أدخل رمز إعادة التعيين';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get passwordResetSuccessful => 'تمت إعادة تعيين كلمة المرور بنجاح';

  @override
  String get twoFactorTitle => 'المصادقة الثنائية';

  @override
  String twoFactorSubtitle(Object email) {
    return 'أدخل الرمز المكوّن من 6 أرقام من تطبيق المصادقة للحساب $email.';
  }

  @override
  String get twoFactorCode => 'رمز المصادقة';

  @override
  String get twoFactorCodeRequired => 'رمز المصادقة مطلوب';

  @override
  String get twoFactorCodeInvalid => 'أدخل رمزًا صحيحًا من 6 أرقام';

  @override
  String get twoFactorHint => 'افتح Google Authenticator وأدخل الرمز الحالي المكوّن من 6 أرقام.';

  @override
  String get twoFactorVerify => 'تحقق';

  @override
  String get twoFactorBack => 'رجوع';

  @override
  String get twoFactorSuccess => 'تم التحقق الثنائي بنجاح';

  @override
  String get twoFactorSetupTitle => 'Google Authenticator';

  @override
  String get twoFactorSetupSubtitle => 'قم بإعداد المصادقة الثنائية لحماية حسابك بشكل أفضل.';

  @override
  String get twoFactorStep1 => 'الخطوة 1';

  @override
  String get twoFactorScanQr => 'امسح رمز QR هذا باستخدام Google Authenticator أو أدخل المفتاح اليدوي أدناه.';

  @override
  String get twoFactorManualKey => 'المفتاح اليدوي';

  @override
  String get twoFactorManualKeyUnavailable => 'المفتاح اليدوي غير متوفر';

  @override
  String get twoFactorQrUnavailable => 'رمز QR غير متوفر';

  @override
  String get twoFactorStep2 => 'الخطوة 2';

  @override
  String get twoFactorEnterSetupCode => 'أدخل الرمز المكوّن من 6 أرقام الذي أنشأه تطبيق المصادقة.';

  @override
  String get twoFactorEnableButton => 'تفعيل المصادقة الثنائية';

  @override
  String get twoFactorEnabledSuccess => 'تم تفعيل المصادقة الثنائية بنجاح';

  @override
  String get somethingWentWrong => 'حدث خطأ ما';

  @override
  String get twoFactorDisableTitle => 'تعطيل Google Authenticator';

  @override
  String get twoFactorDisableMessage => 'هل تريد فعلاً تعطيل المصادقة الثنائية؟';

  @override
  String get twoFactorDisableButton => 'تعطيل';

  @override
  String get twoFactorDisableCodeTitle => 'أدخل رمز التعطيل';

  @override
  String get twoFactorDisabledSuccess => 'تم تعطيل المصادقة الثنائية بنجاح';

  @override
  String get twoFactorToggleTitle => 'Google Authenticator';

  @override
  String get twoFactorToggleOn => 'المصادقة الثنائية مفعلة';

  @override
  String get twoFactorToggleOff => 'المصادقة الثنائية غير مفعلة';

  @override
  String get twoFactorLoadingStatus => 'جاري التحقق من حالة المصادقة الثنائية...';

  @override
  String get twoFactorDisabling => 'جاري تعطيل المصادقة الثنائية...';

  @override
  String get twoFactorPreparing => 'جاري إعداد رمز QR...';

  @override
  String get twoFactorManualKeyCopied => 'تم نسخ المفتاح اليدوي';

  @override
  String get copy => 'نسخ';

  @override
  String get monthlyRevenue => 'الإيرادات الشهرية';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get averageInvoice => 'متوسط الفاتورة';

  @override
  String get topClients => 'أفضل العملاء';

  @override
  String get revenueCurve => 'منحنى الإيرادات';

  @override
  String get paidVsUnpaid => 'المدفوعة مقابل غير المدفوعة';

  @override
  String get totalLabel => 'الإجمالي';

  @override
  String get paidLabel => 'مدفوعة';

  @override
  String get unpaidLabel => 'غير مدفوعة';

  @override
  String get paymentRate => 'معدل الدفع';

  @override
  String get growthCurve => 'منحنى النمو';

  @override
  String get draftLabel => 'مسودة';

  @override
  String get cancelledLabel => 'ملغاة';

  @override
  String get searchInvoiceClientEmail => 'ابحث عن فاتورة، عميل، بريد...';

  @override
  String get noInvoicesMatchSearch => 'لا توجد فواتير تطابق البحث';

  @override
  String get changeStatus => 'تغيير الحالة';

  @override
  String get markAsPaid => 'تعيين كمدفوع';

  @override
  String get markAsUnpaid => 'تعيين كغير مدفوع';

  @override
  String get validateInvoice => 'اعتماد الفاتورة';

  @override
  String get confirmValidateInvoiceTitle => 'اعتماد هذه الفاتورة؟';

  @override
  String get confirmValidateInvoiceBody => 'هل أنت متأكد من اعتماد هذه الفاتورة؟ لن تتمكن من تعديلها بعد الاعتماد.';

  @override
  String get invoiceLockedAfterValidation => 'تم اعتماد هذه الفاتورة. لم يعد بإمكانك تعديل العناصر أو إضافتها أو حذفها.';

  @override
  String get markAsCancelled => 'تعيين كملغى';

  @override
  String get invoiceStatusUpdated => 'تم تحديث حالة الفاتورة';

  @override
  String get updateFailed => 'فشل في التحديث';

  @override
  String get dueSoon => 'قريب الاستحقاق';

  @override
  String get paid => 'مدفوعة';

  @override
  String get unpaid => 'غير مدفوعة';

  @override
  String get cancelled => 'ملغاة';

  @override
  String get expenseNotesTitle => 'ملاحظات المصاريف';

  @override
  String get createExpenseNoteTitle => 'مصروف جديد';

  @override
  String get searchExpenseHint => 'ابحث حسب العنوان أو الفئة أو الوصف';

  @override
  String get noExpenseNotes => 'لا توجد ملاحظات مصاريف';

  @override
  String get noExpenseNotesMatchSearch => 'لا توجد ملاحظات مصاريف تطابق البحث';

  @override
  String get createYourFirstExpenseNoteToSeeItHere => 'قم بإنشاء أول ملاحظة مصروف لتظهر هنا';

  @override
  String get expenseNotePreviewTitleFallback => 'ملاحظة مصروف';

  @override
  String get expenseStatusUpdated => 'تم تحديث حالة المصروف بنجاح';

  @override
  String get expenseNoteDeletedSuccess => 'تم حذف ملاحظة المصروف بنجاح';

  @override
  String get confirmDeleteTitle => 'تأكيد الحذف';

  @override
  String get confirmDeleteExpenseMessage => 'هل أنت متأكد من حذف هذه الملاحظة؟';

  @override
  String get deleteButton => 'حذف';

  @override
  String get cancelButton => 'إلغاء';

  @override
  String get statusPaid => 'مدفوع';

  @override
  String get statusUnpaid => 'غير مدفوع';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get statusRejected => 'مرفوض';

  @override
  String get markAsPending => 'تعيين كقيد الانتظار';

  @override
  String get markAsRejected => 'تعيين كمرفوض';

  @override
  String get dateLabel => 'التاريخ';

  @override
  String get categoryLabel => 'الفئة';

  @override
  String get editExpenseNoteTitle => 'تعديل المصروف';

  @override
  String get editExpenseNoteSubtitle => 'قم بتحديث تفاصيل ملاحظة المصروف.';

  @override
  String get expenseNoteUpdatedSuccess => 'تم تحديث ملاحظة المصروف بنجاح';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get receiptPathLabel => 'مسار الإيصال';

  @override
  String get receiptPathHint => 'أدخل مسار ملف الإيصال';

  @override
  String get updateButton => 'تحديث';

  @override
  String get createExpenseNoteSubtitle => 'أضف وتتبع ملاحظة مصروف جديدة.';

  @override
  String get expenseNoteCreatedSuccess => 'تم إنشاء ملاحظة المصروف بنجاح';

  @override
  String get title => 'العنوان';

  @override
  String get amount => 'المبلغ';

  @override
  String get description => 'الوصف';

  @override
  String get invalidField => 'قيمة غير صالحة';

  @override
  String get saveButton => 'حفظ';

  @override
  String get notAuthenticated => 'غير مصادق عليه';

  @override
  String currencyChangedTo(String currency) {
    return 'تم تغيير العملة إلى $currency';
  }

  @override
  String languageChangedTo(String language) {
    return 'تم تغيير اللغة إلى $language';
  }

  @override
  String get companyInfoIncompleteTitle => 'معلومات الشركة غير مكتملة';

  @override
  String get companyInfoIncompleteBody => 'يرجى إكمال معلومات شركتك.';

  @override
  String get googleAuthenticator => 'Google Authenticator';

  @override
  String get enableTwoFactorAuthentication => 'تفعيل المصادقة الثنائية';

  @override
  String get monthlyExpenses => 'المصاريف الشهرية';

  @override
  String get netMonthlyRevenue => 'صافي الدخل الشهري';

  @override
  String get alertsTitle => 'التنبيهات';

  @override
  String get alertsSnackbars => 'إشعارات سريعة';

  @override
  String get alertsBanners => 'لافتات';

  @override
  String get alertsDialogs => 'حوارات';

  @override
  String get alertsBottomSheets => 'لوحات سفلية';

  @override
  String get alertSuccessTitle => 'تم بنجاح';

  @override
  String get alertSuccessBody => 'تم الحفظ بنجاح.';

  @override
  String get alertInfoTitle => 'معلومة';

  @override
  String get alertInfoBody => 'هذه رسالة معلوماتية.';

  @override
  String get alertWarningTitle => 'تحذير';

  @override
  String get alertWarningBody => 'تحقق من البيانات قبل المتابعة.';

  @override
  String get alertErrorTitle => 'خطأ';

  @override
  String get alertErrorBody => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get alertConfirmTitle => 'تأكيد الإجراء';

  @override
  String get alertConfirmBody => 'هل تريد المتابعة؟';

  @override
  String get alertBottomSheetTitle => 'يتطلب الانتباه';

  @override
  String get alertBottomSheetBody => 'راجع التفاصيل قبل الحفظ.';

  @override
  String get alertSavedBody => 'تم حفظ التغييرات.';

  @override
  String get alertUndo => 'تراجع';

  @override
  String get alertDismiss => 'إغلاق';

  @override
  String get french => 'الفرنسية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get checkingSession => 'جارٍ التحقق من الجلسة...';

  @override
  String get unitPcs => 'قطعة (pcs)';

  @override
  String get unitKg => 'كغ (Kilogram)';

  @override
  String get unitG => 'غ (Gram)';

  @override
  String get unitL => 'لتر (L)';

  @override
  String get unitM => 'متر (m)';

  @override
  String get unitH => 'ساعة (h)';

  @override
  String get unitDay => 'يوم';

  @override
  String get unitService => 'خدمة';

  @override
  String get invalidPhoneNumber => 'رقم الهاتف غير صالح. مثال: +216 20123456رقم الهاتف غير صالح. مثال: +216 ';

  @override
  String get noResults => 'لا توجد نتائج';

  @override
  String get newCustomer => 'عميل جديد';

  @override
  String get createCustomer => 'إنشاء عميل';

  @override
  String get createFirstCustomerToSeeHere => 'أنشئ أول عميل ليظهر هنا.';

  @override
  String get searchCustomerNameIdEmail => 'ابحث عن عميل أو معرف أو بريد إلكتروني...';

  @override
  String get companies => 'الشركات';

  @override
  String get createYourFirstProduct => 'أنشئ أول منتج لك لبدء إضافة عناصر إلى هذه الفاتورة.';

  @override
  String get individuals => 'الأفراد';

  @override
  String get productAdded => 'تمت إضافة المنتج';

  @override
  String get deleteDraftInvoiceConfirm => 'هل تريد حذف هذه الفاتورة (مسودة)؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get invoiceDeleted => 'تم حذف الفاتورة.';

  @override
  String get mobileSearchHint => 'ابحث عن العملاء والمنتجات والمستندات…';

  @override
  String get enterTwoCharacters => 'أدخل حرفين على الأقل';

  @override
  String get noPermittedResults => 'لا توجد نتائج مسموح بها';

  @override
  String get scanProduct => 'مسح منتج';

  @override
  String get lookingUpBarcode => 'جارٍ البحث عن الرمز الشريطي';

  @override
  String get productNotFoundBarcode => 'لم يتم العثور على المنتج. جرّب رمزًا آخر.';

  @override
  String get pointCameraBarcode => 'وجّه الكاميرا نحو الرمز الشريطي للمنتج';

  @override
  String get toggleTorch => 'تشغيل أو إيقاف المصباح';

  @override
  String get documentsTitle => 'المستندات';

  @override
  String get documentSearchHint => 'ابحث بالرقم أو العميل أو المورّد';

  @override
  String get searchAction => 'بحث';

  @override
  String get allDocuments => 'كل المستندات';

  @override
  String get dates => 'التواريخ';

  @override
  String get clearDates => 'مسح التواريخ';

  @override
  String get documentSourcesFailed => 'مصادر مستندات تعذّر تحميلها.';

  @override
  String get noDocumentsFilters => 'لا توجد مستندات مطابقة لهذه المرشحات.';

  @override
  String get cannotViewDocument => 'لا يمكنك عرض هذا المستند.';

  @override
  String get cannotViewRelatedDocument => 'لا يمكنك عرض هذا المستند المرتبط.';

  @override
  String get previewOrSharePdf => 'معاينة ملف PDF أو مشاركته';

  @override
  String get relatedDocuments => 'المستندات المرتبطة';

  @override
  String get lines => 'الأسطر';

  @override
  String get party => 'الطرف';

  @override
  String get dueExpected => 'الاستحقاق / المتوقع';

  @override
  String get balance => 'الرصيد';

  @override
  String get match => 'المطابقة';

  @override
  String get sourceOrder => 'الطلب المصدر';

  @override
  String get invoiceNumber => 'رقم الفاتورة';

  @override
  String get deliveryNote => 'وصل التسليم';

  @override
  String get exception => 'استثناء';

  @override
  String get exceptionReason => 'سبب الاستثناء';

  @override
  String get source => 'المصدر';

  @override
  String get descriptionLabel => 'الوصف';

  @override
  String get documentLine => 'سطر المستند';

  @override
  String get accepted => 'مقبولة';

  @override
  String get damaged => 'تالفة';

  @override
  String get rejected => 'مرفوضة';

  @override
  String get quantityShort => 'الكمية';

  @override
  String get allStatuses => 'كل الحالات';

  @override
  String get statusDraftMobile => 'مسودة';

  @override
  String get statusOpen => 'مفتوح';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusCancelledMobile => 'ملغى';

  @override
  String get kindInvoice => 'فاتورة';

  @override
  String get kindQuotation => 'عرض سعر';

  @override
  String get kindCreditNote => 'إشعار دائن';

  @override
  String get kindSalesOrder => 'طلب بيع';

  @override
  String get kindDeliveryNote => 'وصل تسليم';

  @override
  String get kindSupplierOrder => 'طلب مورّد';

  @override
  String get kindSupplierReception => 'استلام من المورّد';

  @override
  String get kindSupplierInvoice => 'فاتورة مورّد';

  @override
  String get kindExpense => 'مصروف';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get markAllRead => 'تعليم الكل كمقروء';

  @override
  String get allNotificationsRead => 'تم تعليم كل الإشعارات كمقروءة.';

  @override
  String get notificationNoDestination => 'لا توجد وجهة على الهاتف لهذا الإشعار.';

  @override
  String get searchNotifications => 'البحث في الإشعارات';

  @override
  String get unread => 'غير مقروءة';

  @override
  String get read => 'مقروءة';

  @override
  String get allAreas => 'كل المجالات';

  @override
  String get nothingNeedsAttention => 'لا يوجد ما يتطلب انتباهك.';

  @override
  String get notificationOptions => 'خيارات الإشعار';

  @override
  String get markUnread => 'تعليم كغير مقروء';

  @override
  String get markRead => 'تعليم كمقروء';

  @override
  String get unreadNotifications => 'الإشعارات غير المقروءة';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get salesArea => 'المبيعات';

  @override
  String get stockArea => 'المخزون';

  @override
  String get logisticsArea => 'اللوجستيات';

  @override
  String get purchasingArea => 'المشتريات';

  @override
  String get accountingArea => 'المحاسبة';

  @override
  String get financeReview => 'المراجعة المالية';

  @override
  String get refreshBalances => 'تحديث الأرصدة';

  @override
  String get noMobileDocumentLinked => 'لا يوجد مستند على الهاتف مرتبط بهذا القيد.';

  @override
  String get reviewTab => 'المراجعة';

  @override
  String get receivables => 'المبالغ المستحقة لنا';

  @override
  String get payables => 'المبالغ المستحقة علينا';

  @override
  String get expensesTab => 'المصاريف';

  @override
  String get activityTab => 'النشاط';

  @override
  String get searchPartyDocument => 'ابحث عن طرف أو مستند';

  @override
  String get needsAttention => 'يحتاج إلى انتباه';

  @override
  String get nothingReviewQueue => 'لا توجد عناصر في قائمة المراجعة.';

  @override
  String get accountingAttentionQueue => 'قائمة الاهتمام المحاسبي';

  @override
  String get authoritativeBalances => 'الأرصدة المعتمدة من الخادم';

  @override
  String get updated => 'آخر تحديث';

  @override
  String get expenseReview => 'مراجعة المصاريف';

  @override
  String get matchingIssues => 'مشكلات المطابقة';

  @override
  String get certificatesPending => 'شهادات قيد الانتظار';

  @override
  String get approveExpenses => 'الموافقة على المصاريف';

  @override
  String get viewExpenses => 'عرض المصاريف';

  @override
  String get yourFinanceAccess => 'صلاحياتك المالية';

  @override
  String get customerPaymentLedger => 'سجل دفعات العملاء';

  @override
  String get withholdingCertificates => 'شهادات الخصم من المورد';

  @override
  String get supplierPaymentRecording => 'تسجيل دفعات المورّدين';

  @override
  String get supplierCredits => 'إشعارات دائنة للمورّدين';

  @override
  String get supplierReturns => 'مرتجعات المورّدين';

  @override
  String get accountingReports => 'التقارير المحاسبية';

  @override
  String get backendAmountsNotice => 'يحسب الخادم المبالغ. ويستمر التسجيل والتحقق عبر مسارات العمل الحالية الخاضعة للتدقيق.';

  @override
  String get salesOrdersTitle => 'طلبات البيع';

  @override
  String get deliveriesTitle => 'التسليمات';

  @override
  String get searchOrderClient => 'ابحث عن طلب أو عميل';

  @override
  String get searchDeliveryClientOrder => 'ابحث عن تسليم أو عميل أو طلب';

  @override
  String get salesOrderLabel => 'طلب بيع';

  @override
  String get deliveryLabel => 'تسليم';

  @override
  String get sourceLabel => 'المصدر';

  @override
  String get itemsLabel => 'العناصر';

  @override
  String get quantityLabel => 'الكمية';

  @override
  String get invoicesLabel => 'فواتير';

  @override
  String get deliveriesLabel => 'تسليمات';

  @override
  String get confirmDelivery => 'تأكيد التسليم';

  @override
  String get markDelivered => 'تعليم كمُسلَّم';

  @override
  String get cancelDelivery => 'إلغاء التسليم';

  @override
  String get readyToInvoice => 'جاهز للفوترة';

  @override
  String get supplierReceptionsTitle => 'استلامات المورّدين';

  @override
  String get cannotCreateReception => 'لا يمكنك إنشاء استلامات من المورّدين.';

  @override
  String get noSupplierOrderAvailable => 'لا يوجد طلب مورّد مرسل أو مستلم جزئيًا متاح.';

  @override
  String get selectSupplierOrder => 'اختر طلب مورّد';

  @override
  String get purchaseOrder => 'طلب مورّد';

  @override
  String get receiveOrder => 'استلام طلب';

  @override
  String get searchSupplierOrderDocument => 'ابحث عن مورّد أو طلب أو رقم مستند';

  @override
  String get noSupplierReceptions => 'لم يتم العثور على استلامات مورّدين.';

  @override
  String get receptionLabel => 'استلام';

  @override
  String get confirmSupplierReception => 'تأكيد الاستلام من المورّد؟';

  @override
  String get atomicStockNotice => 'ستُضاف الكميات المقبولة إلى المخزون بشكل ذري. ولا يمكن تعديل الاستلام بعد ذلك.';

  @override
  String get createLinkedExpense => 'إنشاء المصروف المرتبط';

  @override
  String get confirmPostStock => 'التأكيد وترحيل المخزون';

  @override
  String get receptionConfirmed => 'تم تأكيد الاستلام.';

  @override
  String get productLinesPosted => 'سطر منتج تم ترحيله إلى المخزون.';

  @override
  String get receptionDetails => 'تفاصيل الاستلام';

  @override
  String get editDraft => 'تعديل المسودة';

  @override
  String get stockPosted => 'تم ترحيل المخزون';

  @override
  String get stockPending => 'المخزون في الانتظار';

  @override
  String get supplierDeliveryNote => 'وصل تسليم المورّد';

  @override
  String get supplierInvoice => 'فاتورة المورّد';

  @override
  String get received => 'المستلم';

  @override
  String get receptionLines => 'أسطر الاستلام';

  @override
  String get totalHt => 'الإجمالي دون الضريبة';

  @override
  String get vat => 'الأداء على القيمة المضافة';

  @override
  String get totalTtc => 'الإجمالي مع الضريبة';

  @override
  String get postingStock => 'جارٍ ترحيل المخزون…';

  @override
  String get editReception => 'تعديل الاستلام';

  @override
  String get newReception => 'استلام جديد';

  @override
  String get receptionWithoutOrder => 'استلام دون طلب مورّد';

  @override
  String get supplierInvoiceOptional => 'رقم فاتورة المورّد (اختياري)';

  @override
  String get supplierDeliveryNumber => 'رقم وصل تسليم المورّد';

  @override
  String get invoiceDate => 'تاريخ الفاتورة';

  @override
  String get receivedDate => 'تاريخ الاستلام';

  @override
  String get deliveryDateOptional => 'تاريخ وصل التسليم (اختياري)';

  @override
  String get notSet => 'غير محدد';

  @override
  String get receivedQuantities => 'الكميات المستلمة';

  @override
  String get receptionException => 'استثناء الاستلام';

  @override
  String get none => 'لا يوجد';

  @override
  String get overdelivery => 'تسليم زائد';

  @override
  String get noPurchaseOrder => 'دون طلب مورّد';

  @override
  String get internalNotes => 'ملاحظات داخلية';

  @override
  String get takeEvidencePhoto => 'التقاط صورة إثبات';

  @override
  String get chooseEvidencePhoto => 'اختيار صورة إثبات';

  @override
  String get couldNotSelectPhoto => 'تعذّر اختيار الصورة';

  @override
  String get negativeReceptionQuantities => 'لا يمكن أن تكون كميات الاستلام سالبة.';

  @override
  String get enterReceivedQuantity => 'أدخل كمية مستلمة أو أزل السطر.';

  @override
  String get discrepancyReasonRequired => 'سبب الاختلاف مطلوب.';

  @override
  String get selectReceptionLine => 'اختر سطرًا واحدًا على الأقل لهذا الاستلام.';

  @override
  String get explainReceptionException => 'اشرح استثناء الاستلام قبل الحفظ.';

  @override
  String get evidenceUploadFailed => 'تم حفظ الاستلام، لكن تعذّر رفع صورة الإثبات.';

  @override
  String get receptionDraftSaved => 'تم حفظ مسودة استلام المورّد.';

  @override
  String get addDiscrepancyEvidence => 'إضافة إثبات الاختلاف';

  @override
  String get evidenceFileHelp => 'JPEG أو PNG أو WebP؛ بحد أقصى 10 ميغابايت';

  @override
  String get receptionTotals => 'إجماليات الاستلام';

  @override
  String get saveReceptionDraft => 'حفظ مسودة الاستلام';

  @override
  String get ordered => 'المطلوب';

  @override
  String get remaining => 'المتبقي';

  @override
  String get discrepancyReason => 'سبب الاختلاف';

  @override
  String get statusConfirmed => 'مؤكد';

  @override
  String get statusDelivered => 'تم التسليم';

  @override
  String get statusInvoiced => 'تمت فوترته';

  @override
  String get statusReviewed => 'تمت مراجعته';

  @override
  String get statusPartiallyDelivered => 'تم التسليم جزئيًا';

  @override
  String get statusPartiallyReceived => 'تم الاستلام جزئيًا';

  @override
  String get statusSent => 'تم الإرسال';

  @override
  String get supplierLabel => 'المورّد';

  @override
  String get more => 'المزيد';

  @override
  String get noMobileFeatures => 'لم يتم تعيين أي ميزات للهاتف لهذا المستخدم.';
}
