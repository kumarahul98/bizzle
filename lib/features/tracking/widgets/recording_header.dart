import 'dart:async';

import 'package:flutter/material.dart';
import 'package:traevy/config/theme.dart';

/// Pulsing recording indicator + direction label shown at the top of the
/// active tracking screen (Variant A). Replaces the old AppBar.
///
/// See: `.planning/phases/08-ui-overhaul/08-UI-SPEC.md` §4 Active Recording.
class RecordingHeader extends StatefulWidget {
  /// Creates a [RecordingHeader] with the given [directionLabel].
  const RecordingHeader({required this.directionLabel, super.key});

  /// Short human-readable label, e.g. 'To office' or 'To home'.
  final String directionLabel;

  @override
  State<RecordingHeader> createState() => _RecordingHeaderState();
}

class _RecordingHeaderState extends State<RecordingHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacity = Tween<double>(begin: 0.5, end: 1).animate(_controller);
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: <Widget>[
          AnimatedBuilder(
            animation: _opacity,
            builder: (context, _) => Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.record,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'RECORDING',
            style: TraevyFonts.ui(
              size: 12,
              weight: FontWeight.w700,
              color: tokens.record,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          Text(
            widget.directionLabel,
            style: TraevyFonts.ui(
              size: 12,
              weight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
