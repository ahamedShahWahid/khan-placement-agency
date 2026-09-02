import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/l10n/app_localizations.dart';

void main() {
  test('generated AppLocalizations stays in sync with the ARB sources', () {
    // `generate: true` reruns gen_l10n automatically on every build/test, so
    // this pins ARB -> codegen -> the committed lib/l10n/app_localizations*
    // files end-to-end (the tests below only check the raw ARB inputs).
    expect(
      AppLocalizations.supportedLocales,
      containsAll(const [Locale('en'), Locale('hi')]),
    );
    final hi = lookupAppLocalizations(const Locale('hi'));
    expect(hi.commonRetry, matches(RegExp('[ऀ-ॿ]')));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.commonRetry, 'Retry');
  });

  test('en and hi ARB files declare identical key sets', () {
    final en =
        json.decode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final hi =
        json.decode(File('lib/l10n/app_hi.arb').readAsStringSync())
            as Map<String, dynamic>;
    Set<String> keys(Map<String, dynamic> m) =>
        m.keys.where((k) => !k.startsWith('@')).toSet();
    expect(
      keys(hi),
      keys(en),
      reason: 'app_hi.arb must mirror every app_en.arb key',
    );
  });

  test('hi values are Devanagari-bearing (spot check)', () {
    final hi =
        json.decode(File('lib/l10n/app_hi.arb').readAsStringSync())
            as Map<String, dynamic>;
    final values = hi.entries
        .where((e) => !e.key.startsWith('@') && e.value is String)
        .map((e) => e.value as String);
    final devanagari = RegExp('[ऀ-ॿ]');
    final bearing = values.where(devanagari.hasMatch).length;
    expect(
      bearing,
      greaterThan(values.length ~/ 2),
      reason: 'most Hindi strings should contain Devanagari',
    );
  });
}
