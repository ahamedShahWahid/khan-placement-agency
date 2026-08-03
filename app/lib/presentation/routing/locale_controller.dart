import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// The app's current locale override.
///
/// `null` means "follow the device locale" (resolved by
/// `AppLocalizations.localizationsDelegates` / `localeResolutionCallback` in
/// `lib/app.dart`). Set explicitly by the language switcher (Task 8) and by
/// the post-sign-in preferences load path once the server's `language`
/// preference arrives.
///
/// Deliberately plain `@riverpod` (autoDispose), not `keepAlive` — but the
/// root `MaterialApp` watches it (`lib/app.dart`), which keeps it alive for
/// the app's lifetime same as any other watched autoDispose provider.
/// [reset] must be called from every sign-out path (alongside the existing
/// `ref.invalidate(preferencesControllerProvider)` calls) so the next
/// session doesn't inherit the previous applicant's language.
@riverpod
class LocaleController extends _$LocaleController {
  @override
  Locale? build() => null;

  /// Maps a server/UI language code to a [Locale]. Unrecognised values fall
  /// back to English rather than propagating an invalid locale.
  void setFromLanguage(String language) =>
      state = language == 'hi' ? const Locale('hi') : const Locale('en');

  /// Back to device-follow — call from every path that pushes `SignedOut`.
  void reset() => state = null;
}
