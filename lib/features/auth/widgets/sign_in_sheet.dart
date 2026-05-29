import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/config/theme.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/onboarding/widgets/google_continue_button.dart';

/// Shows the sign-in bottom sheet.
///
/// Mirrors `_openThemePicker` in `settings_screen.dart` exactly:
/// `showModalBottomSheet` with `surfaceContainerLowest` background and
/// `showDragHandle: true`, dismissable by drag or scrim tap.
///
/// On successful sign-in the sheet dismisses itself. From Settings the
/// Account section re-renders to the populated `AccountRow` via
/// `authStateProvider` — there is NO confirmation-screen push from this sheet
/// (the one-time confirmation is the onboarding-first-sign-in path only).
///
/// Security invariants (T-09-05-02):
///   * No Firebase ID token or credential is ever passed to `print` /
///     `debugPrint` / `log` inside this widget.
///   * Cancel (`GoogleSignInException`) is a silent no-op — sheet stays open,
///     no toast, no error copy.
///   * Network/credential failure shows `kCopySignInFailedHeadline` /
///     `kCopySignInFailedBody` and keeps the sheet open with the CTA
///     re-enabled.
Future<void> showSignInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    showDragHandle: true,
    builder: (sheetCtx) {
      return const _SignInSheetContent();
    },
  );
}

/// Content widget for the sign-in bottom sheet. Extracted to keep the builder
/// closure lean and to allow `ConsumerWidget` access to Riverpod providers
/// inside the sheet (the outer `builder` context does not have a `WidgetRef`).
class _SignInSheetContent extends ConsumerStatefulWidget {
  const _SignInSheetContent();

  @override
  ConsumerState<_SignInSheetContent> createState() =>
      _SignInSheetContentState();
}

class _SignInSheetContentState extends ConsumerState<_SignInSheetContent> {
  bool _isLoading = false;
  bool _hasFailed = false;

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });

    try {
      await ref.read(authServiceProvider).signIn();
      // Success: pop the sheet. Guard with mounted check (context.mounted
      // discipline from trip_actions.dart lines 42, 48).
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on GoogleSignInException {
      // User cancelled the account picker — silent no-op (T-09-05-01).
      // Keep the sheet open; the CTA returns to its enabled state.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } on Object {
      // Network / credential error — show in-sheet error copy, keep open,
      // CTA re-enabled (UI-SPEC §B / T-09-05-02).
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final tokens = Theme.of(context).extension<TraevyTokensExt>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 24),
            Icon(
              Icons.g_translate_rounded,
              size: 20,
              color: onSurface,
            ),
            const SizedBox(height: 12),
            Text(
              kCopySignInSheetHeadline,
              style: TraevyFonts.ui(
                size: 22,
                weight: FontWeight.w700,
                letterSpacing: -0.6,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              kCopySignInSheetSubtext,
              style: TraevyFonts.ui(
                size: 16,
                color: tokens.textDim,
                height: 1.5,
              ),
            ),
            if (_hasFailed) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                kCopySignInFailedHeadline,
                style: TraevyFonts.ui(
                  size: 15,
                  weight: FontWeight.w600,
                  color: tokens.record,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kCopySignInFailedBody,
                style: TraevyFonts.ui(
                  size: 14,
                  color: tokens.textDim,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (firebaseReady && !_isLoading)
              // Enabled path: button wired to signIn().
              GoogleContinueButton(onTap: _handleSignIn)
            else if (firebaseReady && _isLoading)
              // Loading state: button disabled during in-flight sign-in.
              Opacity(
                opacity: kDisabledSignInOpacity,
                child: Tooltip(
                  message: '',
                  child: Semantics(
                    enabled: false,
                    child: GoogleContinueButton(onTap: () {}),
                  ),
                ),
              )
            else
              // D-15 degrade path: Firebase not configured.
              // Disabled with tooltip + Semantics(enabled: false) (T-09-05-03).
              Opacity(
                opacity: kDisabledSignInOpacity,
                child: Tooltip(
                  message: kCopySignInDisabledTooltip,
                  child: Semantics(
                    enabled: false,
                    child: GoogleContinueButton(onTap: () {}),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
