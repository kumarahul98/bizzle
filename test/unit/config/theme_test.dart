// ignore_for_file: uri_does_not_exist
// Wave-0 RED test for buildLightTheme() and buildDarkTheme().
//
// This file tests the new Traevy-branded theme functions that do not yet exist
// in lib/config/theme.dart. The compile or assertion failure is the deliberate
// RED state. Plan 02 rewrites theme.dart to turn this GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/config/theme.dart';

void main() {
  group('buildLightTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = buildLightTheme();
    });

    test('returns a ThemeData instance', () {
      expect(theme, isA<ThemeData>());
    });

    test('brightness is Brightness.light', () {
      expect(theme.brightness, Brightness.light);
    });

    test('useMaterial3 is true', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('colorScheme.primary equals light accent Color(0xFF3A5F8F)', () {
      expect(theme.colorScheme.primary, const Color(0xFF3A5F8F));
    });

    test('colorScheme.error equals light danger Color(0xFFC0392B)', () {
      expect(theme.colorScheme.error, const Color(0xFFC0392B));
    });

    test('scaffoldBackgroundColor equals light bg Color(0xFFFAFAF7)', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAF7));
    });
  });

  group('buildDarkTheme', () {
    late ThemeData theme;

    setUp(() {
      theme = buildDarkTheme();
    });

    test('returns a ThemeData instance', () {
      expect(theme, isA<ThemeData>());
    });

    test('brightness is Brightness.dark', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('useMaterial3 is true', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('colorScheme.primary equals dark accent Color(0xFF8AABCF)', () {
      expect(theme.colorScheme.primary, const Color(0xFF8AABCF));
    });

    test('colorScheme.error equals dark danger Color(0xFFE05A4A)', () {
      expect(theme.colorScheme.error, const Color(0xFFE05A4A));
    });

    test('scaffoldBackgroundColor equals dark bg Color(0xFF1A1B22)', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A1B22));
    });
  });
}
