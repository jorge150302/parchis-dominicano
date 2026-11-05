import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/config/language_provider.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/widgets/ai_fill_offer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'language_code': 'es'});
    await PrefsService.init();
  });

  testWidgets('explains the offer, the XP cost, and accepts on tap', (tester) async {
    var accepted = 0;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: Scaffold(body: AiFillOffer(onAccept: () => accepted++))),
    ));
    await tester.pumpAndSettle();

    final es = LanguageProvider.translations[Language.es]!;
    expect(find.text(es['ai_fill_offer']!), findsOneWidget);
    expect(find.text(es['ai_fill_xp_hint']!), findsOneWidget);
    expect(accepted, 0, reason: 'never accepted on its own');

    await tester.tap(find.text(es['ai_fill_button']!));
    expect(accepted, 1);
  });
}
