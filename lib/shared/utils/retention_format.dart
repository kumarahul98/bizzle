import 'package:traevy/config/constants.dart';

/// Format the Trash retention countdown for a soft-deleted trip (Phase 35,
/// D-05), e.g. `Deleted 3 days ago · auto-removes in 27 days`.
///
/// [deletedAtUtc] is the trip's `deletedAt` tombstone and [nowUtc] the current
/// instant; both are compared in UTC. [retentionDays] defaults to
/// [kTrashRetentionDays] so the copy can never disagree with the purge window.
///
/// The countdown is always computed, never stored — a stored value would be
/// wrong the moment the app is closed for a day. The age is clamped to zero so
/// a future-dated tombstone (a clock moved backward) reads "Deleted today"
/// with the full window remaining rather than a negative age. The "remaining"
/// half hits [kTrashAutoRemovesSoonLabel] once the window is exhausted — the
/// trip is then due for purge on the next app start.
String formatRetentionCountdown({
  required DateTime deletedAtUtc,
  required DateTime nowUtc,
  int retentionDays = kTrashRetentionDays,
}) {
  final rawAgeDays = nowUtc.difference(deletedAtUtc).inDays;
  final ageDays = rawAgeDays < 0 ? 0 : rawAgeDays;
  final remaining = (retentionDays - ageDays).clamp(0, retentionDays);

  final deletedPart = ageDays == 0
      ? kTrashDeletedTodayLabel
      : '$kTrashDeletedPrefix$ageDays ${_dayNoun(ageDays)}$kTrashAgoSuffix';
  final removesPart = remaining == 0
      ? kTrashAutoRemovesSoonLabel
      : '$kTrashAutoRemovesInPrefix$remaining ${_dayNoun(remaining)}';

  return '$deletedPart$kTrashCountdownSeparator$removesPart';
}

String _dayNoun(int days) => days == 1 ? kTrashDayWord : kTrashDaysWord;
