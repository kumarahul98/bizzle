import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flutter test bootstrapping hook. Runs once before all tests in any
/// `test/` subtree. Disables google_fonts runtime network fetching so
/// widget tests never attempt to download fonts (Pitfall 2 in
/// .planning/phases/08-ui-overhaul/08-RESEARCH.md).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
