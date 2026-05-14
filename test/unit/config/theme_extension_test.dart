// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for TraevyTokensExt ThemeExtension.
//
// This file tests TraevyTokensExt.fromTokens(), TraevyTokens.light/dark, and
// full lerp coverage across all 14 token fields. These classes do not yet
// exist in lib/config/theme.dart. The compile or assertion failure is the
// deliberate RED state. Plan 02 creates the production types that turn this
// GREEN.
//
// Review MEDIUM #3: Theme extension lerp test must cover ALL 14 TraevyTokensExt
// fields — not just a single field like bgElev.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group A — fromTokens round-trip
  // ---------------------------------------------------------------------------
  group('TraevyTokensExt.fromTokens round-trip', () {
    test('light extension moving color equals Color(0xFF2E8B57)', () {
      final ext = TraevyTokensExt.fromTokens(TraevyTokens.light);
      expect(ext.moving, const Color(0xFF2E8B57));
    });

    test('light extension accent color equals Color(0xFF3A5F8F)', () {
      final ext = TraevyTokensExt.fromTokens(TraevyTokens.light);
      expect(ext.accent, const Color(0xFF3A5F8F));
    });

    test('light extension record color equals Color(0xFFC0392B)', () {
      final ext = TraevyTokensExt.fromTokens(TraevyTokens.light);
      expect(ext.record, const Color(0xFFC0392B));
    });

    test('dark extension moving color equals Color(0xFF5BC88A)', () {
      final ext = TraevyTokensExt.fromTokens(TraevyTokens.dark);
      expect(ext.moving, const Color(0xFF5BC88A));
    });

    test('dark extension accent color equals Color(0xFF8AABCF)', () {
      final ext = TraevyTokensExt.fromTokens(TraevyTokens.dark);
      expect(ext.accent, const Color(0xFF8AABCF));
    });

    test('dark extension record color equals Color(0xFFE05A4A)', () {
      final ext = TraevyTokensExt.fromTokens(TraevyTokens.dark);
      expect(ext.record, const Color(0xFFE05A4A));
    });
  });

  // ---------------------------------------------------------------------------
  // Group B — Full-field lerp midpoint coverage (t=0.5)
  //
  // All 14 TraevyTokensExt fields must be covered. Each row corresponds to:
  //   Light hex → Dark hex, interpolated at t=0.5.
  //
  // Field table (from 08-CONTEXT.md):
  //   bgElev    : 0xFFFFFFFF  → 0xFF22242E
  //   surface2  : 0xFFEEEEE8  → 0xFF2A2C38
  //   border    : 0xFFE5E5DF  → 0xFF2E3040
  //   borderStr : 0xFFD4D4CE  → 0xFF383A4A
  //   textDim   : 0xFF6B6B7A  → 0xFFA0A0B8
  //   textMuted : 0xFF9A9AAA  → 0xFF6E6E88
  //   moving    : 0xFF2E8B57  → 0xFF5BC88A
  //   movingBg  : 0xFFDCF2E4  → 0xFF1E3D2E
  //   stuck     : 0xFFC4820A  → 0xFFD4A832
  //   stuckBg   : 0xFFF5EDDA  → 0xFF3A2E10
  //   accent    : 0xFF3A5F8F  → 0xFF8AABCF
  //   accentBg  : 0xFFE8EEF5  → 0xFF1E2A38
  //   record    : 0xFFC0392B  → 0xFFE05A4A
  //   mapBg     : 0xFFF4F4EE  → 0xFF1D1F27
  // ---------------------------------------------------------------------------
  group('TraevyTokensExt lerp — full 14-field midpoint coverage (t=0.5)', () {
    late TraevyTokensExt mid;

    setUpAll(() {
      mid = TraevyTokensExt.fromTokens(
        TraevyTokens.light,
      ).lerp(TraevyTokensExt.fromTokens(TraevyTokens.dark), 0.5)!;
    });

    test('bgElev midpoint', () {
      expect(
        mid.bgElev,
        Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF22242E), 0.5),
      );
    });

    test('surface2 midpoint', () {
      expect(
        mid.surface2,
        Color.lerp(const Color(0xFFEEEEE8), const Color(0xFF2A2C38), 0.5),
      );
    });

    test('border midpoint', () {
      expect(
        mid.border,
        Color.lerp(const Color(0xFFE5E5DF), const Color(0xFF2E3040), 0.5),
      );
    });

    test('borderStr midpoint', () {
      expect(
        mid.borderStr,
        Color.lerp(const Color(0xFFD4D4CE), const Color(0xFF383A4A), 0.5),
      );
    });

    test('textDim midpoint', () {
      expect(
        mid.textDim,
        Color.lerp(const Color(0xFF6B6B7A), const Color(0xFFA0A0B8), 0.5),
      );
    });

    test('textMuted midpoint', () {
      expect(
        mid.textMuted,
        Color.lerp(const Color(0xFF9A9AAA), const Color(0xFF6E6E88), 0.5),
      );
    });

    test('moving midpoint', () {
      expect(
        mid.moving,
        Color.lerp(const Color(0xFF2E8B57), const Color(0xFF5BC88A), 0.5),
      );
    });

    test('movingBg midpoint', () {
      expect(
        mid.movingBg,
        Color.lerp(const Color(0xFFDCF2E4), const Color(0xFF1E3D2E), 0.5),
      );
    });

    test('stuck midpoint', () {
      expect(
        mid.stuck,
        Color.lerp(const Color(0xFFC4820A), const Color(0xFFD4A832), 0.5),
      );
    });

    test('stuckBg midpoint', () {
      expect(
        mid.stuckBg,
        Color.lerp(const Color(0xFFF5EDDA), const Color(0xFF3A2E10), 0.5),
      );
    });

    test('accent midpoint', () {
      expect(
        mid.accent,
        Color.lerp(const Color(0xFF3A5F8F), const Color(0xFF8AABCF), 0.5),
      );
    });

    test('accentBg midpoint', () {
      expect(
        mid.accentBg,
        Color.lerp(const Color(0xFFE8EEF5), const Color(0xFF1E2A38), 0.5),
      );
    });

    test('record midpoint', () {
      expect(
        mid.record,
        Color.lerp(const Color(0xFFC0392B), const Color(0xFFE05A4A), 0.5),
      );
    });

    test('mapBg midpoint', () {
      expect(
        mid.mapBg,
        Color.lerp(const Color(0xFFF4F4EE), const Color(0xFF1D1F27), 0.5),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group C — lerp boundary cases
  // ---------------------------------------------------------------------------
  group('TraevyTokensExt lerp boundary cases', () {
    late TraevyTokensExt light;
    late TraevyTokensExt dark;

    setUp(() {
      light = TraevyTokensExt.fromTokens(TraevyTokens.light);
      dark = TraevyTokensExt.fromTokens(TraevyTokens.dark);
    });

    test('lerp at t=0.0 returns colors equal to the light source', () {
      final result = light.lerp(dark, 0.0)!;
      expect(result.bgElev, light.bgElev);
      expect(result.surface2, light.surface2);
      expect(result.border, light.border);
      expect(result.borderStr, light.borderStr);
      expect(result.textDim, light.textDim);
      expect(result.textMuted, light.textMuted);
      expect(result.moving, light.moving);
      expect(result.movingBg, light.movingBg);
      expect(result.stuck, light.stuck);
      expect(result.stuckBg, light.stuckBg);
      expect(result.accent, light.accent);
      expect(result.accentBg, light.accentBg);
      expect(result.record, light.record);
      expect(result.mapBg, light.mapBg);
    });

    test('lerp at t=1.0 returns colors equal to the dark source', () {
      final result = light.lerp(dark, 1.0)!;
      expect(result.bgElev, dark.bgElev);
      expect(result.surface2, dark.surface2);
      expect(result.border, dark.border);
      expect(result.borderStr, dark.borderStr);
      expect(result.textDim, dark.textDim);
      expect(result.textMuted, dark.textMuted);
      expect(result.moving, dark.moving);
      expect(result.movingBg, dark.movingBg);
      expect(result.stuck, dark.stuck);
      expect(result.stuckBg, dark.stuckBg);
      expect(result.accent, dark.accent);
      expect(result.accentBg, dark.accentBg);
      expect(result.record, dark.record);
      expect(result.mapBg, dark.mapBg);
    });

    test('lerp(null, 0.5) returns this unchanged', () {
      final result = light.lerp(null, 0.5);
      expect(result?.bgElev, light.bgElev);
      expect(result?.moving, light.moving);
      expect(result?.accent, light.accent);
    });

    test('lerp with non-TraevyTokensExt other returns this unchanged', () {
      // Create a stub ThemeExtension that is not a TraevyTokensExt.
      final stub = _StubThemeExtension();
      final result = light.lerp(stub, 0.5);
      expect(result?.bgElev, light.bgElev);
      expect(result?.moving, light.moving);
      expect(result?.accent, light.accent);
    });
  });
}

/// Stub ThemeExtension used to test lerp's type-guard behaviour.
///
/// Extends `ThemeExtension<TraevyTokensExt>` (not `TraevyTokensExt` itself)
/// so it satisfies the `lerp` parameter type while still failing the
/// `other is! TraevyTokensExt` guard — confirming that `lerp` returns `this`
/// when the other extension is the wrong concrete type.
class _StubThemeExtension extends ThemeExtension<TraevyTokensExt> {
  @override
  ThemeExtension<TraevyTokensExt> copyWith() => _StubThemeExtension();

  @override
  ThemeExtension<TraevyTokensExt> lerp(
    covariant ThemeExtension<TraevyTokensExt>? other,
    double t,
  ) =>
      this;
}
