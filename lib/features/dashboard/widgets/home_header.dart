import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';

/// Dashboard home header: date + greeting on the left, avatar circle on
/// the right.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §3 Home / Dashboard.
class HomeHeader extends StatelessWidget {
  /// Create the home header.
  const HomeHeader({super.key});

  static String _formatDate(DateTime now) {
    final weekday = DateFormat('EEE').format(now);
    final monthDay = DateFormat('d MMM').format(now);
    return '$weekday · $monthDay';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(now).toUpperCase(),
                style: TraevyFonts.ui(
                  size: 11,
                  weight: FontWeight.w600,
                  letterSpacing: 1,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hi, $kPlaceholderUserName',
                style: textTheme.titleLarge,
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                kPlaceholderUserInitial,
                style: TraevyFonts.ui(
                  size: 14,
                  weight: FontWeight.w700,
                  color: tokens.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
