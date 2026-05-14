import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// A single row in the TripTimeline widget.
///
/// Displays a time label, an icon in a colored circle, an event label,
/// and an optional duration string (used for the stuck-in-traffic row).
class TripTimelineRow extends StatelessWidget {
  /// Creates a [TripTimelineRow].
  const TripTimelineRow({
    required this.time,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.duration,
    super.key,
  });

  /// Local time to display in the left column (HH:mm format).
  final DateTime time;

  /// Icon shown in the colored circle.
  final IconData icon;

  /// Background color of the icon circle.
  final Color iconBg;

  /// Color of the icon itself.
  final Color iconColor;

  /// Event description (e.g. 'Started recording').
  final String label;

  /// Optional duration string shown right-aligned (e.g. '18 min').
  final String? duration;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final textTheme = Theme.of(context).textTheme;
    final timeLabel = _formatHm(time);

    return Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(
            timeLabel,
            style: TraevyFonts.mono(size: 12, color: tokens.textDim),
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: textTheme.bodyMedium)),
        if (duration != null)
          Text(
            duration!,
            style: TraevyFonts.mono(
              size: 12,
              weight: FontWeight.w600,
              color: tokens.stuck,
            ),
          ),
      ],
    );
  }

  String _formatHm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
