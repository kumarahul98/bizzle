import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Non-Material Traevy color tokens registered as a [ThemeExtension] on
/// every Phase 8 [ThemeData]. Widgets read them via
/// `Theme.of(context).extension<TraevyTokensExt>()!`.
///
/// The 14 fields here are the tokens that sit outside the Material
/// [ColorScheme] surface — primarily semantic colors (`moving`, `stuck`,
/// `accent`, `record`) and surface variants (`bgElev`, `surface2`, `border`,
/// `borderStr`, `mapBg`) that do not have 1:1 [ColorScheme] slots.
///
/// See: `.planning/phases/08-ui-overhaul/08-CONTEXT.md` Design Tokens block.
@immutable
class TraevyTokensExt extends ThemeExtension<TraevyTokensExt> {
  /// Construct a [TraevyTokensExt] directly.
  ///
  /// Prefer [TraevyTokensExt.fromTokens] in production — pass a
  /// [TraevyTokens] instance so the 14 fields are populated from the
  /// locked hex table in one call.
  const TraevyTokensExt({
    required this.bgElev,
    required this.surface2,
    required this.border,
    required this.borderStr,
    required this.textDim,
    required this.textMuted,
    required this.moving,
    required this.movingBg,
    required this.stuck,
    required this.stuckBg,
    required this.accent,
    required this.accentBg,
    required this.record,
    required this.mapBg,
  });

  /// Construct a [TraevyTokensExt] from a [TraevyTokens] data class,
  /// copying the 14 non-Material token fields.
  ///
  /// Used by `buildLightTheme()` and `buildDarkTheme()` in
  /// `lib/config/theme.dart` to register the extension on [ThemeData].
  factory TraevyTokensExt.fromTokens(TraevyTokens t) => TraevyTokensExt(
    bgElev: t.bgElev,
    surface2: t.surface2,
    border: t.border,
    borderStr: t.borderStr,
    textDim: t.textDim,
    textMuted: t.textMuted,
    moving: t.moving,
    movingBg: t.movingBg,
    stuck: t.stuck,
    stuckBg: t.stuckBg,
    accent: t.accent,
    accentBg: t.accentBg,
    record: t.record,
    mapBg: t.mapBg,
  );

  // -------------------------------------------------------------------------
  // Surface / elevation tokens
  // -------------------------------------------------------------------------

  /// Elevated surface background — cards, sheets, bottom bars.
  /// Light: #FFFFFF | Dark: #22242E
  final Color bgElev;

  /// Secondary surface — subtle inset panels, grouped rows.
  /// Light: #EEEEE8 | Dark: #2A2C38
  final Color surface2;

  /// Default border / divider color.
  /// Light: #E5E5DF | Dark: #2E3040
  final Color border;

  /// Strong border — selected states, focused outlines.
  /// Light: #D4D4CE | Dark: #383A4A
  final Color borderStr;

  // -------------------------------------------------------------------------
  // Text tokens
  // -------------------------------------------------------------------------

  /// Dimmed text — secondary labels, subtitles.
  /// Light: #6B6B7A | Dark: #A0A0B8
  final Color textDim;

  /// Muted text — placeholder, helper text, icon labels.
  /// Light: #9A9AAA | Dark: #6E6E88
  final Color textMuted;

  // -------------------------------------------------------------------------
  // Semantic / data tokens
  // -------------------------------------------------------------------------

  /// Moving-state indicator color (speed ≥ 10 km/h).
  /// Light: #2E8B57 | Dark: #5BC88A
  final Color moving;

  /// Background behind `moving`-colored elements.
  /// Light: #DCF2E4 | Dark: #1E3D2E
  final Color movingBg;

  /// Stuck-state indicator color (speed < 10 km/h).
  /// Light: #C4820A | Dark: #D4A832
  final Color stuck;

  /// Background behind `stuck`-colored elements.
  /// Light: #F5EDDA | Dark: #3A2E10
  final Color stuckBg;

  /// Brand accent / interactive highlight color.
  /// Light: #3A5F8F | Dark: #8AABCF
  final Color accent;

  /// Background behind accent-colored elements.
  /// Light: #E8EEF5 | Dark: #1E2A38
  final Color accentBg;

  /// Record / destructive action indicator (same as danger in this design).
  /// Light: #C0392B | Dark: #E05A4A
  final Color record;

  /// Map tile background used in the faux-map placeholder widget.
  /// Light: #F4F4EE | Dark: #1D1F27
  final Color mapBg;

  // -------------------------------------------------------------------------
  // ThemeExtension overrides
  // -------------------------------------------------------------------------

  @override
  TraevyTokensExt copyWith({
    Color? bgElev,
    Color? surface2,
    Color? border,
    Color? borderStr,
    Color? textDim,
    Color? textMuted,
    Color? moving,
    Color? movingBg,
    Color? stuck,
    Color? stuckBg,
    Color? accent,
    Color? accentBg,
    Color? record,
    Color? mapBg,
  }) => TraevyTokensExt(
    bgElev: bgElev ?? this.bgElev,
    surface2: surface2 ?? this.surface2,
    border: border ?? this.border,
    borderStr: borderStr ?? this.borderStr,
    textDim: textDim ?? this.textDim,
    textMuted: textMuted ?? this.textMuted,
    moving: moving ?? this.moving,
    movingBg: movingBg ?? this.movingBg,
    stuck: stuck ?? this.stuck,
    stuckBg: stuckBg ?? this.stuckBg,
    accent: accent ?? this.accent,
    accentBg: accentBg ?? this.accentBg,
    record: record ?? this.record,
    mapBg: mapBg ?? this.mapBg,
  );

  /// Interpolates every one of the 14 color fields between `this` and [other]
  /// at parameter [t].
  ///
  /// **Review MEDIUM #3:** Every field below MUST be lerped. If any field is
  /// omitted, the corresponding token will snap discontinuously during a theme
  /// transition, causing a visible flash. The Plan 01 test
  /// `theme_extension_test.dart` asserts the t=0.5 midpoint for ALL 14 fields
  /// and fails if any are missing.
  ///
  /// Returns `this` unchanged when [other] is `null` or not a
  /// [TraevyTokensExt] instance.
  /// Interpolates every one of the 14 color fields between `this` and [other]
  /// at parameter [t].
  ///
  /// **Review MEDIUM #3:** Every field MUST be lerped. If any field is
  /// omitted, the corresponding token will snap discontinuously during a theme
  /// transition, causing a visible flash. The Plan 01 test
  /// `theme_extension_test.dart` asserts the t=0.5 midpoint for ALL 14 fields
  /// and fails if any are missing.
  ///
  /// Returns `this` unchanged when [other] is `null` or not a
  /// [TraevyTokensExt] instance.
  @override
  TraevyTokensExt lerp(ThemeExtension<TraevyTokensExt>? other, double t) {
    if (other is! TraevyTokensExt) return this;
    return TraevyTokensExt(
      bgElev: Color.lerp(bgElev, other.bgElev, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStr: Color.lerp(borderStr, other.borderStr, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      moving: Color.lerp(moving, other.moving, t)!,
      movingBg: Color.lerp(movingBg, other.movingBg, t)!,
      stuck: Color.lerp(stuck, other.stuck, t)!,
      stuckBg: Color.lerp(stuckBg, other.stuckBg, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBg: Color.lerp(accentBg, other.accentBg, t)!,
      record: Color.lerp(record, other.record, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
    );
  }
}
