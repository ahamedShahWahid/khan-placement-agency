// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrivacyController)
final privacyControllerProvider = PrivacyControllerProvider._();

final class PrivacyControllerProvider
    extends $AsyncNotifierProvider<PrivacyController, PrivacyState> {
  PrivacyControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'privacyControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$privacyControllerHash();

  @$internal
  @override
  PrivacyController create() => PrivacyController();
}

String _$privacyControllerHash() => r'0f42da358e627d44dcca80e288ad61e39b4a9958';

abstract class _$PrivacyController extends $AsyncNotifier<PrivacyState> {
  FutureOr<PrivacyState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PrivacyState>, PrivacyState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PrivacyState>, PrivacyState>,
        AsyncValue<PrivacyState>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
