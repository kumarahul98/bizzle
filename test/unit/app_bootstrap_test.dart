import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/app.dart';
import 'package:traevy/config/theme.dart';

void main() {
  group('TraevyApp bootstrap', () {
    testWidgets(
      'pumps inside ProviderScope and renders PlaceholderHome',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: TraevyApp()),
        );

        // MaterialApp is configured with the expected title and themes.
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.title, 'Traevy');
        expect(materialApp.theme, lightTheme);
        expect(materialApp.darkTheme, darkTheme);
        expect(materialApp.themeMode, ThemeMode.system);

        // PlaceholderHome renders an AppBar title and body text.
        expect(find.byType(PlaceholderHome), findsOneWidget);
        expect(find.text('Traevy'), findsWidgets);
        expect(find.text('Traevy Phase 1'), findsOneWidget);
      },
    );
  });
}
