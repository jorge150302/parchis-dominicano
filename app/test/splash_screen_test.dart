import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen displays Image widget and handles timer', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      routes: {
        '/menu': (_) => const Scaffold(body: Text('Menu')),
      },
      home: const SplashScreen(),
    ));

    // Verify that the Image widget is present.
    expect(find.byType(Image), findsOneWidget);

    // Wait for the timer to finish to avoid "Timer still pending" error.
    await tester.pump(const Duration(milliseconds: 2000));
    // Pump again to allow navigation to occur
    await tester.pump();
    
    // Optional: verify navigation happened
    expect(find.text('Menu'), findsOneWidget);
  });
}
