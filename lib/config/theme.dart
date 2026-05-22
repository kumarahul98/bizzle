// ignore_for_file: use_enums // TraevyTokens holds mutable Color instance
// fields that cannot appear on Dart enum members, so the class pattern is
// intentional even though it has only static const instances and a private
// constructor.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme_extension.dart';

// Re-export so callers that import only theme.dart also get TraevyTokensExt.
export 'package:traevy/config/theme_extension.dart';

// ---------------------------------------------------------------------------
// TraevyTokens — immutable design token data class
// ---------------------------------------------------------------------------

/// Immutable container for all 18 Traevy color design tokens.
///
/// Two pre-built instances cover the light and dark color palettes:
/// [TraevyTokens.light] and [TraevyTokens.dark].
///
/// Color values are sRGB hex approximations of the original oklch tokens
/// from the Traevy design handoff. See:
/// `.planning/phases/08-ui-overhaul/08-CONTEXT.md` — Design Tokens block.
@immutable
class TraevyTokens {
  const TraevyTokens._({
    required this.bg,
    required this.bgElev,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderStr,
    required this.text,
    required this.textDim,
    required this.textMuted,
    required this.moving,
    required this.movingBg,
    required this.stuck,
    required this.stuckBg,
    required this.accent,
    required this.accentBg,
    required this.danger,
    required this.record,
    required this.mapBg,
  });

  // -------------------------------------------------------------------------
  // Light palette — oklch 0.985 0.003 80 baseline
  // -------------------------------------------------------------------------

  /// Light-mode Traevy token set.
  ///
  /// Hex values locked per the design handoff table in
  /// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
  static const TraevyTokens light = TraevyTokens._(
    bg: Color(0xFFFAFAF7),
    bgElev: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F5F0),
    surface2: Color(0xFFEEEEE8),
    border: Color(0xFFE5E5DF),
    borderStr: Color(0xFFD4D4CE),
    text: Color(0xFF2A2A38),
    textDim: Color(0xFF6B6B7A),
    textMuted: Color(0xFF9A9AAA),
    moving: Color(0xFF2E8B57),
    movingBg: Color(0xFFDCF2E4),
    stuck: Color(0xFFC4820A),
    stuckBg: Color(0xFFF5EDDA),
    accent: Color(0xFF3A5F8F),
    accentBg: Color(0xFFE8EEF5),
    danger: Color(0xFFC0392B),
    record: Color(0xFFC0392B),
    mapBg: Color(0xFFF4F4EE),
  );

  // -------------------------------------------------------------------------
  // Dark palette — oklch 0.16 0.006 250 baseline
  // -------------------------------------------------------------------------

  /// Dark-mode Traevy token set.
  ///
  /// Hex values locked per the design handoff table in
  /// `.planning/phases/08-ui-overhaul/08-CONTEXT.md`.
  static const TraevyTokens dark = TraevyTokens._(
    bg: Color(0xFF1A1B22),
    bgElev: Color(0xFF22242E),
    surface: Color(0xFF24262F),
    surface2: Color(0xFF2A2C38),
    border: Color(0xFF2E3040),
    borderStr: Color(0xFF383A4A),
    text: Color(0xFFF2F2F7),
    textDim: Color(0xFFA0A0B8),
    textMuted: Color(0xFF6E6E88),
    moving: Color(0xFF5BC88A),
    movingBg: Color(0xFF1E3D2E),
    stuck: Color(0xFFD4A832),
    stuckBg: Color(0xFF3A2E10),
    accent: Color(0xFF8AABCF),
    accentBg: Color(0xFF1E2A38),
    danger: Color(0xFFE05A4A),
    record: Color(0xFFE05A4A),
    mapBg: Color(0xFF1D1F27),
  );

  // -------------------------------------------------------------------------
  // Token fields — 18 total
  // -------------------------------------------------------------------------

  /// App / scaffold background. The lowest surface layer.
  final Color bg;

  /// Elevated surface — cards, bottom sheets, navigation bars.
  final Color bgElev;

  /// Primary surface — modal backgrounds, inset panels.
  final Color surface;

  /// Secondary surface — grouped rows, input backgrounds.
  final Color surface2;

  /// Default divider / border color.
  final Color border;

  /// Strong border — selected outlines, focus rings.
  final Color borderStr;

  /// Primary text color.
  final Color text;

  /// Secondary / dimmed text — subtitles, secondary labels.
  final Color textDim;

  /// Placeholder / muted text — helper text, icon labels.
  final Color textMuted;

  /// Moving indicator (speed ≥ 10 km/h). Warm green.
  final Color moving;

  /// Background tint behind moving-state elements.
  final Color movingBg;

  /// Stuck indicator (speed < 10 km/h). Muted amber.
  final Color stuck;

  /// Background tint behind stuck-state elements.
  final Color stuckBg;

  /// Brand accent / interactive highlight. Blue-slate.
  final Color accent;

  /// Background tint behind accent-colored elements.
  final Color accentBg;

  /// Destructive / error color — delete, error states.
  final Color danger;

  /// Active-recording indicator. Same hue as [danger] by design.
  final Color record;

  /// Map tile background used in faux-map placeholder widgets.
  final Color mapBg;
}

// ---------------------------------------------------------------------------
// Shared UI constants derived from design tokens
// ---------------------------------------------------------------------------

/// Shadow color for toggle knob and elevated pill components — 20% opaque
/// black, matching the UI-SPEC §8 TraevyToggle BoxShadow contract.
const Color kTraevyKnobShadow = Color(0x33000000);

// ---------------------------------------------------------------------------
// TraevyFonts — TextStyle factory helpers
// ---------------------------------------------------------------------------

/// TextStyle factory helpers for the two Traevy typefaces.
///
/// - [ui] returns an Inter [TextStyle] — used for all body copy, labels,
///   buttons, and headings (all non-numeric UI text).
/// - [mono] returns a JetBrains Mono [TextStyle] — used for all numeric
///   values: duration, distance, speed, percentages, time strings.
///
/// Both delegate to the `google_fonts` package so that the font is resolved
/// from the bundled TTF assets in `assets/fonts/` (runtime fetching is
/// disabled in `main.dart` via
/// `GoogleFonts.config.allowRuntimeFetching = false`).
///
/// See: `.planning/phases/08-ui-overhaul/08-CONTEXT.md` — Typography block.
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §1.
class TraevyFonts {
  TraevyFonts._();

  /// Inter [TextStyle] for UI text (headings, labels, body copy).
  ///
  /// [size] — `fontSize` in logical pixels (required).
  /// [weight] — `fontWeight`, defaults to [FontWeight.w400].
  /// [color] — `color`, optional.
  /// [letterSpacing] — `letterSpacing`, defaults to 0.
  /// [height] — `height` (line-height multiplier), optional.
  static TextStyle ui({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
    double? height,
  }) => TextStyle(
    fontFamily: kFontUI,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// JetBrains Mono [TextStyle] for numeric / monospace data displays.
  ///
  /// [size] — `fontSize` in logical pixels (required).
  /// [weight] — `fontWeight`, defaults to [FontWeight.w400].
  /// [color] — `color`, optional.
  /// [letterSpacing] — `letterSpacing`, defaults to 0.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: kFontMono,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

// ---------------------------------------------------------------------------
// buildLightTheme / buildDarkTheme — MaterialApp theme factories
// ---------------------------------------------------------------------------

/// Build the Traevy light [ThemeData].
///
/// Wires [TraevyTokens.light] into a Material 3 theme and registers
/// [TraevyTokensExt] as a [ThemeExtension] so downstream widgets can read
/// non-Material tokens via `Theme.of(context).extension<TraevyTokensExt>()!`.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §1.
ThemeData buildLightTheme() => _build(TraevyTokens.light, Brightness.light);

/// Build the Traevy dark [ThemeData].
///
/// Wires [TraevyTokens.dark] into a Material 3 theme and registers
/// [TraevyTokensExt] as a [ThemeExtension].
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §1.
ThemeData buildDarkTheme() => _build(TraevyTokens.dark, Brightness.dark);

/// Private factory that wires a [TraevyTokens] set into a fully-populated
/// Material 3 [ThemeData].
///
/// The [ColorScheme] is constructed explicitly (no `ColorScheme.fromSeed`) so
/// that every slot maps to a named Traevy token — preventing the implicit
/// tonal-palette generation that overrides manually chosen colors.
/// See Pitfall 3 in `.planning/phases/08-ui-overhaul/08-RESEARCH.md`.
ThemeData _build(TraevyTokens t, Brightness b) {
  final colorScheme = ColorScheme(
    brightness: b,
    primary: t.accent,
    onPrimary: t.bg,
    secondary: t.moving,
    onSecondary: t.bg,
    error: t.danger,
    onError: Colors.white,
    surface: t.bg,
    onSurface: t.text,
    surfaceContainerLowest: t.bgElev,
    surfaceContainerLow: t.bgElev,
    surfaceContainer: t.surface,
    surfaceContainerHigh: t.surface2,
    surfaceContainerHighest: t.surface2,
    outline: t.border,
    outlineVariant: t.borderStr,
    onSurfaceVariant: t.textDim,
  );

  // Build a base Inter TextTheme, then override specific roles with exact
  // Traevy spec sizes/weights/letter-spacing.
  final baseTextTheme = GoogleFonts.interTextTheme(
    ThemeData(brightness: b).textTheme,
  ).apply(bodyColor: t.text, displayColor: t.text);

  final textTheme = baseTextTheme.copyWith(
    displaySmall: TraevyFonts.ui(
      size: 36,
      weight: FontWeight.w700,
      letterSpacing: -1.2,
      color: t.text,
      height: 1.05,
    ),
    titleLarge: TraevyFonts.ui(
      size: 22,
      weight: FontWeight.w700,
      letterSpacing: -0.6,
      color: t.text,
    ),
    bodyLarge: TraevyFonts.ui(size: 15, weight: FontWeight.w500, color: t.text),
    bodyMedium: TraevyFonts.ui(
      size: 13,
      weight: FontWeight.w500,
      color: t.text,
    ),
    labelLarge: TraevyFonts.ui(
      size: 14,
      weight: FontWeight.w600,
      color: t.text,
    ),
    labelMedium: TraevyFonts.ui(
      size: 12,
      weight: FontWeight.w600,
      letterSpacing: 1,
      color: t.textMuted,
    ),
    labelSmall: TraevyFonts.ui(
      size: 11,
      weight: FontWeight.w600,
      letterSpacing: 1,
      color: t.textMuted,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: t.bg,
    textTheme: textTheme,
    // Pitfall 4 — elevation: 0, explicit border shape, EdgeInsets.zero margin.
    cardTheme: CardThemeData(
      elevation: 0,
      color: t.bgElev,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.border),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TraevyFonts.ui(
        size: 22,
        weight: FontWeight.w700,
        color: t.text,
        letterSpacing: -0.6,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.bgElev,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TraevyFonts.ui(
          size: 10.5,
          letterSpacing: 0.1,
          weight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? t.text : t.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? t.text : t.textMuted,
          size: 22,
        );
      }),
    ),
    dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: t.text, size: 22),
    extensions: <ThemeExtension<dynamic>>[TraevyTokensExt.fromTokens(t)],
  );
}
