import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 8 IndexedStack tab-index provider — Review HIGH #1 safe.
///
/// Owns the selected tab index for the main shell. Non-autoDispose (kept-alive)
/// so tab switch state persists for the lifetime of the app. Changing tabs
/// is a state update, NOT a route push — see UI-SPEC.md §2 and
/// Review MEDIUM #4.
///
/// Phase 8 IndexedStack — must persist across tab switches (Review HIGH #1).
final NotifierProvider<MainShellIndexNotifier, int> mainShellIndexProvider =
    NotifierProvider<MainShellIndexNotifier, int>(
      MainShellIndexNotifier.new,
      name: 'mainShellIndexProvider',
    );

/// Notifier for [mainShellIndexProvider].
///
/// Clamps [setIndex] to the valid range [0, 3] to guard against off-by-one
/// callers. [build] returns 0 (Today tab) as the default.
class MainShellIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Switch the active tab to [i].
  ///
  /// Silently ignores out-of-range values to prevent IndexedStack errors.
  void setIndex(int i) {
    if (i >= 0 && i < 4) state = i;
  }
}
