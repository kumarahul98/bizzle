import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/features/tracking/screens/home_screen.dart';

void main() {
  testWidgets(
    'TraevyApp builds under ProviderScope and shows HomeScreen',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: TraevyApp()));
      await tester.pumpAndSettle();

      // Root widget tree is a MaterialApp — proves the wiring through
      // ProviderScope reached TraevyApp without throwing.
      expect(find.byType(MaterialApp), findsOneWidget);

      // Phase 2 mounts HomeScreen as the root.
      expect(find.byType(HomeScreen), findsOneWidget);

      // AppBar title uses 'Traevy' and body exposes the Start commute
      // CTA. 'Traevy' appears both in the AppBar and the MaterialApp
      // title chrome, so use findsWidgets instead of findsOneWidget.
      expect(find.text('Traevy'), findsWidgets);
      expect(find.text('Start commute'), findsOneWidget);
    },
  );
}
