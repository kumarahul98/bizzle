// Unit tests for the dashboard header's identity derivation (Phase 32, D-01).
//
// These are pure functions over the sealed AuthState — no widget, no
// ProviderScope, no Firebase. They exist because the null-displayName case is
// already handled upstream in AuthStateNotifier but the empty and
// whitespace-only cases are NOT, and either one renders a blank avatar if the
// derivation does not trim before splitting.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/constants.dart';
import 'package:traevy/features/auth/models/auth_state.dart';
import 'package:traevy/features/dashboard/widgets/home_header.dart';

AuthState _signedInAs(String name) =>
    AuthSignedIn(uid: 'u1', name: name, email: 'you@traevy.app');

void main() {
  group('HomeHeader.greetingName (SC#1, SC#2)', () {
    test('full name yields the first word', () {
      expect(HomeHeader.greetingName(_signedInAs('Ada Lovelace')), 'Ada');
    });

    test('three-part name still yields only the first word', () {
      expect(
        HomeHeader.greetingName(_signedInAs('Ada Byron King Lovelace')),
        'Ada',
      );
    });

    test('single name yields that name unchanged', () {
      expect(HomeHeader.greetingName(_signedInAs('Ada')), 'Ada');
    });

    test('empty display name falls back to the guest name', () {
      expect(HomeHeader.greetingName(_signedInAs('')), kPlaceholderUserName);
    });

    test('whitespace-only display name falls back to the guest name', () {
      expect(HomeHeader.greetingName(_signedInAs('   ')), kPlaceholderUserName);
      expect(
        HomeHeader.greetingName(_signedInAs('\t\n ')),
        kPlaceholderUserName,
      );
    });

    test('leading and trailing spaces are trimmed away', () {
      expect(
        HomeHeader.greetingName(_signedInAs('  Ada Lovelace  ')),
        'Ada',
      );
    });

    test('runs of inner whitespace do not leak into the first word', () {
      expect(HomeHeader.greetingName(_signedInAs('Ada\t Lovelace')), 'Ada');
    });

    test('a non-Latin first character survives intact', () {
      expect(HomeHeader.greetingName(_signedInAs('李 明')), '李');
      expect(HomeHeader.greetingName(_signedInAs('Élodie Martin')), 'Élodie');
      expect(HomeHeader.greetingName(_signedInAs('अनुराग शर्मा')), 'अनुराग');
    });

    test('guest and loading both use the guest fallback', () {
      expect(HomeHeader.greetingName(const AuthGuest()), kPlaceholderUserName);
      expect(
        HomeHeader.greetingName(const AuthLoading()),
        kPlaceholderUserName,
      );
    });
  });

  group('HomeHeader.avatarInitial (SC#1, SC#2)', () {
    test('uses the uppercased first letter of the first name', () {
      expect(HomeHeader.avatarInitial(_signedInAs('Ada Lovelace')), 'A');
      expect(HomeHeader.avatarInitial(_signedInAs('ada lovelace')), 'A');
    });

    test('never renders blank for empty or whitespace-only names', () {
      for (final name in <String>['', '   ', '\t']) {
        final initial = HomeHeader.avatarInitial(_signedInAs(name));
        expect(initial, kPlaceholderUserInitial);
        expect(initial.trim(), isNotEmpty);
      }
    });

    test('leading spaces do not produce a blank initial', () {
      expect(HomeHeader.avatarInitial(_signedInAs('  Ada')), 'A');
    });

    test('a non-Latin first character is not split mid-grapheme', () {
      expect(HomeHeader.avatarInitial(_signedInAs('李 明')), '李');
      expect(HomeHeader.avatarInitial(_signedInAs('अनुराग')), 'अ');
      // toUpperCase() is a no-op for scripts without case; the point is that
      // exactly one grapheme comes back, never half a code-point pair.
      expect(HomeHeader.avatarInitial(_signedInAs('Ωmega')), 'Ω');
    });

    test('guest and loading both show the guest initial', () {
      expect(
        HomeHeader.avatarInitial(const AuthGuest()),
        kPlaceholderUserInitial,
      );
      expect(
        HomeHeader.avatarInitial(const AuthLoading()),
        kPlaceholderUserInitial,
      );
    });

    test('the initial always agrees with the greeting name', () {
      for (final name in <String>['Ada Lovelace', 'ada', '', '  ', '李 明']) {
        final auth = _signedInAs(name);
        expect(
          HomeHeader.avatarInitial(auth),
          HomeHeader.greetingName(auth).characters.first.toUpperCase(),
        );
      }
    });
  });
}
