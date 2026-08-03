import 'dart:async';

import 'package:jobify_app/data/preferences/preferences_dto.dart';
import 'package:jobify_app/data/preferences/preferences_repository_impl.dart';
import 'package:jobify_app/data/preferences/preferences_update_dto.dart';
import 'package:jobify_app/presentation/routing/locale_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_controller.g.dart';

@Riverpod(keepAlive: true)
class PreferencesController extends _$PreferencesController {
  @override
  Future<PreferencesDto> build() async {
    final prefs = await ref.read(preferencesRepositoryProvider).fetch();
    // Server value always wins, unconditionally (including "en") — this is
    // the ONLY thing that closes the shared-device stale-locale window: a
    // 401-forced sign-out never calls LocaleController.reset(), so the next
    // applicant's first preferences load must overwrite whatever locale the
    // previous session left behind rather than trusting it's already right.
    ref.read(localeControllerProvider.notifier).setFromLanguage(prefs.language);
    return prefs;
  }

  Future<bool> submit(PreferencesUpdateDto update) async {
    // Preserve the loaded value across the submit: this provider is
    // keepAlive and shared (ProfileScreen, FeedSummaryRow,
    // EditProfileScreen), so a bare AsyncLoading/AsyncError here would
    // radiate a data-less state to every watcher.
    final previous = state;
    // ignore: invalid_use_of_internal_member
    state = const AsyncValue<PreferencesDto>.loading().copyWithPrevious(
      previous,
    );
    final result = await AsyncValue.guard(
      () => ref.read(preferencesRepositoryProvider).update(update),
    );
    if (result.hasError) {
      final error =
          AsyncValue<PreferencesDto>.error(result.error!, result.stackTrace!);
      // ignore: invalid_use_of_internal_member
      state = error.copyWithPrevious(previous);
      // The language switcher optimistically flips the app locale before
      // this save lands (see ProfileScreen). On failure, restore whatever
      // language the last successfully-loaded preferences carried — a no-op
      // for saves that never touched language.
      if (previous.value case final prev?) {
        ref
            .read(localeControllerProvider.notifier)
            .setFromLanguage(prev.language);
      }
      return false;
    }
    state = AsyncValue.data(result.value!);
    return true;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
