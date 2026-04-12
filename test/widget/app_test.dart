import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';

void main() {
  testWidgets(
    'TraevyApp builds under ProviderScope and shows placeholder home',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: TraevyApp()));
      await tester.pumpAndSettle();

      // Root widget tree is a MaterialApp — proves the wiring through
      // ProviderScope reached TraevyApp without throwing.
      expect(find.byType(MaterialApp), findsOneWidget);

      // AppBar title uses 'Traevy' and body uses the phase-1 placeholder.
      // 'Traevy' appears both in the AppBar and the MaterialApp title
      // chrome, so use findsWidgets instead of findsOneWidget.
      expect(find.text('Traevy'), findsWidgets);
      expect(find.text('Traevy Phase 1'), findsOneWidget);
    },
  );
}
