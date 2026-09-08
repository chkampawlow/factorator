import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/l10n/app_localizations_ar.dart';
import 'package:my_app/l10n/app_localizations_en.dart';
import 'package:my_app/l10n/app_localizations_fr.dart';
import 'package:my_app/l10n/mobile_labels.dart';

void main() {
  test('workflow statuses are localized without changing backend codes', () {
    final en = AppLocalizationsEn();
    final fr = AppLocalizationsFr();
    final ar = AppLocalizationsAr();

    expect(localizedWorkflowStatus(en, 'PARTIALLY_RECEIVED'),
        'Partially received');
    expect(localizedWorkflowStatus(fr, 'PARTIALLY_RECEIVED'),
        'Partiellement reçu');
    expect(localizedWorkflowStatus(ar, 'PARTIALLY_RECEIVED'),
        'تم الاستلام جزئيًا');
  });

  test('search entity labels use the active language', () {
    final fr = AppLocalizationsFr();
    final ar = AppLocalizationsAr();

    expect(localizedSearchType(fr, 'Supplier order'), 'Commande fournisseur');
    expect(localizedSearchType(ar, 'Client'), 'العميل');
  });

  test('reception exception codes have user-facing translations', () {
    final en = AppLocalizationsEn();
    final fr = AppLocalizationsFr();
    final ar = AppLocalizationsAr();

    expect(localizedReceptionException(en, 'NO_ORDER'), 'No purchase order');
    expect(localizedReceptionException(fr, 'OVERDELIVERY'), 'Sur-livraison');
    expect(localizedReceptionException(ar, 'NONE'), 'لا يوجد');
  });
}
