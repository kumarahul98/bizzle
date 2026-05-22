import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Account header row inside the Settings → Account section: a 44dp
/// `accentBg` avatar circle with the user's initial, name, and email.
///
/// Currently fed by the `kPlaceholderUserName` / `kPlaceholderUserInitial`
/// constants until authentication ships in Phase 9. The signature accepts
/// runtime values so the Phase 9 wiring is a constructor swap, not a
/// widget rewrite.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §8 Settings Screen.
class AccountRow extends StatelessWidget {
  /// Creates an [AccountRow].
  ///
  /// [name] is the display name shown next to the avatar.
  /// [email] is the secondary line rendered in JetBrains Mono.
  /// [initial] is the single character rendered inside the avatar circle.
  const AccountRow({
    required this.name,
    required this.email,
    required this.initial,
    super.key,
  });

  /// User's display name (Inter 15sp w600).
  final String name;

  /// User's email (JetBrains Mono 12sp dim).
  final String email;

  /// Single-character initial rendered inside the avatar circle.
  final String initial;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.accentBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: TraevyFonts.ui(
                  size: 16,
                  weight: FontWeight.w700,
                  color: tokens.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TraevyFonts.ui(
                    size: 15,
                    weight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TraevyFonts.mono(size: 12, color: tokens.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
