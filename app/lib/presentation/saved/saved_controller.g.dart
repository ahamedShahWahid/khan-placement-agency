// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SavedController)
final savedControllerProvider = SavedControllerProvider._();

final class SavedControllerProvider
    extends $AsyncNotifierProvider<SavedController, SavedState> {
  SavedControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'savedControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$savedControllerHash();

  @$internal
  @override
  SavedController create() => SavedController();
}

String _$savedControllerHash() => r'18b3fa6b65ce031ba8fbc51f7f1f64f6d2519277';

abstract class _$SavedController extends $AsyncNotifier<SavedState> {
  FutureOr<SavedState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SavedState>, SavedState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<SavedState>, SavedState>,
        AsyncValue<SavedState>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
