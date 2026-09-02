// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(LocaleController)
final localeControllerProvider = LocaleControllerProvider._();

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
final class LocaleControllerProvider
    extends $NotifierProvider<LocaleController, Locale?> {
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
  LocaleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeControllerHash();

  @$internal
  @override
  LocaleController create() => LocaleController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale?>(value),
    );
  }
}

String _$localeControllerHash() => r'7814734ea38bbc994c10aa5ad9db6a3fa8739c88';

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

abstract class _$LocaleController extends $Notifier<Locale?> {
  Locale? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Locale?, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Locale?, Locale?>,
              Locale?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
