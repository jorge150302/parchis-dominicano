import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/config/language_provider.dart';
import 'package:frontend_parchis/screens/privacy_policy_screen.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.init();
    // Force Spanish for the test
    await PrefsService.setLanguage('es');
  });

  testWidgets('PrivacyPolicyScreen displays title and sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify title is shown
    expect(find.text('POLÍTICA DE PRIVACIDAD'), findsOneWidget);
    
    // Verify some section title
    expect(find.text('1. Información que Recopilamos'), findsOneWidget);
  });
}
