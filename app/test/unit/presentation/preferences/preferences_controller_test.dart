import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/core/error/exceptions.dart';
import 'package:jobify_app/data/preferences/desired_role.dart';
import 'package:jobify_app/data/preferences/preferences_dto.dart';
import 'package:jobify_app/data/preferences/preferences_repository.dart';
import 'package:jobify_app/data/preferences/preferences_repository_impl.dart';
import 'package:jobify_app/data/preferences/preferences_update_dto.dart';
import 'package:jobify_app/presentation/preferences/preferences_controller.dart';
import 'package:jobify_app/presentation/routing/locale_controller.dart';

const _en = PreferencesDto(
  desiredRole: null,
  locations: ['Pune'],
  expectedCtc: null,
);

const _hi = PreferencesDto(
  desiredRole: null,
  locations: ['Pune'],
  expectedCtc: null,
  language: 'hi',
);

class _OkRepo implements PreferencesRepository {
  _OkRepo(this._fetchResult, {PreferencesDto? updateResult})
      : _updateResult = updateResult ?? _fetchResult;
  final PreferencesDto _fetchResult;
  final PreferencesDto _updateResult;

  @override
  Future<PreferencesDto> fetch() async => _fetchResult;

  @override
  Future<PreferencesDto> update(PreferencesUpdateDto update) async =>
      _updateResult;
}

class _FailingUpdateRepo implements PreferencesRepository {
  _FailingUpdateRepo(this._fetchResult);
  final PreferencesDto _fetchResult;

  @override
  Future<PreferencesDto> fetch() async => _fetchResult;

  @override
  Future<PreferencesDto> update(PreferencesUpdateDto update) async =>
      throw const ApiException(statusCode: 500, slug: 'boom');
}

void main() {
  test(
    'build() calls localeController.setFromLanguage with the loaded '
    'language, unconditionally (including "en")',
    () async {
      final c = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(_OkRepo(_en)),
        ],
      );
      addTearDown(c.dispose);
      // Keep the autoDispose LocaleController alive for the test's duration.
      final sub = c.listen(localeControllerProvider, (_, __) {});
      addTearDown(sub.close);

      // Seed a stale previous-user locale, as a shared-device 401-forced
      // sign-out would leave behind (it never resets LocaleController).
      c.read(localeControllerProvider.notifier).setFromLanguage('hi');
      expect(c.read(localeControllerProvider), const Locale('hi'));

      await c.read(preferencesControllerProvider.future);

      expect(c.read(localeControllerProvider), const Locale('en'));
    },
  );

  test(
    'build() flips the locale to "hi" when the server preference is "hi"',
    () async {
      final c = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(_OkRepo(_hi)),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(localeControllerProvider, (_, __) {});
      addTearDown(sub.close);

      await c.read(preferencesControllerProvider.future);

      expect(c.read(localeControllerProvider), const Locale('hi'));
    },
  );

  test('submit success returns true', () async {
    final c = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(_OkRepo(_en)),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(localeControllerProvider, (_, __) {});
    addTearDown(sub.close);
    await c.read(preferencesControllerProvider.future);

    const update = PreferencesUpdateDto(
      desiredRole: DesiredRole.unknown,
      locations: ['Pune'],
      expectedCtc: null,
      language: 'en',
    );
    final ok =
        await c.read(preferencesControllerProvider.notifier).submit(update);

    expect(ok, isTrue);
  });

  test(
    'failed save rolls the locale back to the previously-loaded language',
    () async {
      final c = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider
              .overrideWithValue(_FailingUpdateRepo(_en)),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(localeControllerProvider, (_, __) {});
      addTearDown(sub.close);

      // Preferences loaded with language "en" — build() sets the locale.
      await c.read(preferencesControllerProvider.future);
      expect(c.read(localeControllerProvider), const Locale('en'));

      // Language switcher optimistically flips to "hi" before the save
      // lands.
      c.read(localeControllerProvider.notifier).setFromLanguage('hi');
      expect(c.read(localeControllerProvider), const Locale('hi'));

      const update = PreferencesUpdateDto(
        desiredRole: DesiredRole.unknown,
        locations: ['Pune'],
        expectedCtc: null,
        language: 'hi',
      );
      final ok =
          await c.read(preferencesControllerProvider.notifier).submit(update);

      expect(ok, isFalse);
      expect(c.read(preferencesControllerProvider).hasError, isTrue);
      // Rolled back to the last successfully-loaded language, not "hi".
      expect(c.read(localeControllerProvider), const Locale('en'));
    },
  );
}
