import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/trips/services/trip_edit_recompute.dart';
import 'package:traevy/features/trips/widgets/break_editor_list.dart';

void main() {
  group('BreakEditorList', () {
    final defaultStart = DateTime.utc(2026, 1, 1, 8);
    final defaultEnd = DateTime.utc(2026, 1, 1, 8, 5);

    /// Host that owns the break list and rebuilds on onChanged so the editor
    /// reflects add/remove the way the real edit sheet does.
    Widget host() {
      return MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: _Host(defaultStart: defaultStart, defaultEnd: defaultEnd),
        ),
      );
    }

    testWidgets('renders the section header and Add break button', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(find.text(kEditBreaksSectionLabel), findsOneWidget);
      expect(find.text(kEditAddBreakLabel), findsOneWidget);
    });

    testWidgets('Add break grows the list by one in-window default', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.tap(find.text(kEditAddBreakLabel));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.text(kEditAddBreakLabel));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
    });

    testWidgets('removing a row shrinks the list', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text(kEditAddBreakLabel));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.defaultStart, required this.defaultEnd});

  final DateTime defaultStart;
  final DateTime defaultEnd;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  List<EditBreakSegment> _breaks = const <EditBreakSegment>[];

  @override
  Widget build(BuildContext context) {
    return BreakEditorList(
      breaks: _breaks,
      onChanged: (next) => setState(() => _breaks = next),
      defaultStart: widget.defaultStart,
      defaultEnd: widget.defaultEnd,
    );
  }
}
