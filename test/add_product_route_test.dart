import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/add_product_screen.dart';

void main() {
  testWidgets('add form opens on a route without shell AccessScope', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AddProductScreen(initialItemType: 'SERVICE'),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
  });
}
