import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/tracking/providers/tracking_providers.dart';

/// Modal dialog shown when an interrupted trip is detected on launch.
/// Offers Resume and Discard options.
class RecoveryPromptDialog extends ConsumerWidget {
  /// Constructor.
  const RecoveryPromptDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          kRecoveryDialogTitle,
          style: TraevyFonts.ui(
            size: 22,
            weight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.2,
          ),
        ),
        content: Text(
          kRecoveryDialogBody,
          style: TraevyFonts.ui(
            size: 13,
            weight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final notifier = ref.read(trackingStateProvider.notifier);
              unawaited(notifier.discardInterruptedTrip());
              // Transition pops the dialog (handled by MainShell listener).
            },
            child: Text(
              kRecoveryDiscardAction,
              style: TraevyFonts.ui(
                size: 14,
                weight: FontWeight.w600,
                color: tokens.record, // Destructive action
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final notifier = ref.read(trackingStateProvider.notifier);
              unawaited(notifier.resumeInterruptedTrip());
              // Transition pops the dialog (handled by MainShell listener).
            },
            child: Text(
              kRecoveryResumeAction,
              style: TraevyFonts.ui(
                size: 14,
                weight: FontWeight.w600,
                color: tokens.accent, // Primary action
              ),
            ),
          ),
        ],
      ),
    );
  }
}
