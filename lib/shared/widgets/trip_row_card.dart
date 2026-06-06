import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/shared/widgets/trip_row_info.dart';

/// Trip row for the history list: direction avatar, name, duration, time
/// range, distance, and optional stuck indicator.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §5 Trip History.
class TripRowCard extends StatelessWidget {
  const TripRowCard({
    required this.direction,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.stuckSeconds,
    this.isEdited = false,
    this.showDivider = true,
    this.onTap,
    super.key,
  });

  final String direction;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double distanceMeters;
  final int stuckSeconds;

  /// True for a trip that has been fully edited (Phase 19, D-04). Surfaces the
  /// "~ estimated" hint on the row's stuck figure. Defaults to false so
  /// existing call sites compile unchanged.
  final bool isEdited;
  final bool showDivider;
  final VoidCallback? onTap;

  static String _dur(int s) {
    final m = s ~/ 60;
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }

  static String _dist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  static String _name(String d) =>
      d == kDirectionToOffice ? 'To office' : 'To home';

  static final _fmt = DateFormat.Hm();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final isOffice = direction == kDirectionToOffice;
    final s = _fmt.format(startTime);
    final e = _fmt.format(endTime);
    final timeRange = '$s → $e · ${_dist(distanceMeters)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isOffice
                        ? tokens.accentBg
                        : tokens.movingBg,
                    child: Icon(
                      isOffice
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      color: isOffice ? tokens.accent : tokens.moving,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TripRowInfo(
                      displayName: _name(direction),
                      durationLabel: _dur(durationSeconds),
                      timeRange: timeRange,
                      stuckMins: stuckSeconds ~/ 60,
                      isEdited: isEdited,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) Divider(color: tokens.border, thickness: 1, height: 1),
      ],
    );
  }
}
