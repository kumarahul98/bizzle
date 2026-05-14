import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/features/dashboard/screens/dashboard_screen.dart';
import 'package:traevy/features/settings/screens/settings_screen.dart';
import 'package:traevy/features/shell/providers/main_shell_provider.dart';
import 'package:traevy/features/stats/screens/stats_screen.dart';
import 'package:traevy/features/trips/screens/history_screen.dart';

/// Root shell widget implementing the Traevy 4-tab bottom-navigation layout.
///
/// Uses [IndexedStack] to keep all four tab screens simultaneously mounted so
/// each tab preserves its own scroll position and provider state across tab
/// switches — see `.planning/phases/08-ui-overhaul/08-RESEARCH.md` Pattern 3
/// and the IndexedStack safety guarantee at
/// `.planning/phases/08-ui-overhaul/08-04-PROVIDER-AUDIT.md`.
///
/// **Back-button behaviour (Review MEDIUM #4):** [MainShell] deliberately does
/// NOT wrap in a [PopScope]. Tab switches are state updates on
/// [mainShellIndexProvider], not route pushes — so the Navigator stack contains
/// only the root MainShell route. Pressing the system back button from any tab
/// behaves the same as pressing it on the Dashboard: the OS treats it as "exit
/// the app". This is the correct Android bottom-nav behaviour — back from Stats
/// reached via tab switch must NOT navigate back to Dashboard.
class MainShell extends ConsumerWidget {
  /// Create the main shell.
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(mainShellIndexProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const <Widget>[
          DashboardScreen(),
          HistoryScreen(),
          StatsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref
            .read(mainShellIndexProvider.notifier)
            .setIndex,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
