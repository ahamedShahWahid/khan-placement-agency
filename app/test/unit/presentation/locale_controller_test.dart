import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/presentation/routing/locale_controller.dart';

void main() {
  test('build defaults to null (follow device locale)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Keep the autoDispose provider alive for the test's duration.
    final sub = c.listen(localeControllerProvider, (_, __) {});
    addTearDown(sub.close);

    expect(c.read(localeControllerProvider), isNull);
  });

  test("setFromLanguage('hi') sets Locale('hi')", () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(localeControllerProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(localeControllerProvider.notifier).setFromLanguage('hi');
    expect(c.read(localeControllerProvider), const Locale('hi'));
  });

  test("setFromLanguage('en') sets Locale('en')", () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(localeControllerProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(localeControllerProvider.notifier).setFromLanguage('en');
    expect(c.read(localeControllerProvider), const Locale('en'));
  });

  test('unrecognised language falls back to English', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(localeControllerProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(localeControllerProvider.notifier).setFromLanguage('fr');
    expect(c.read(localeControllerProvider), const Locale('en'));
  });

  test('reset() returns to null (device-follow) after being set', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(localeControllerProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(localeControllerProvider.notifier).setFromLanguage('hi');
    expect(c.read(localeControllerProvider), const Locale('hi'));

    c.read(localeControllerProvider.notifier).reset();
    expect(c.read(localeControllerProvider), isNull);
  });
}
