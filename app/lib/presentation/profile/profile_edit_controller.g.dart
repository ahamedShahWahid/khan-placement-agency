// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_edit_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProfileEditController)
final profileEditControllerProvider = ProfileEditControllerProvider._();

final class ProfileEditControllerProvider
    extends $AsyncNotifierProvider<ProfileEditController, void> {
  ProfileEditControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'profileEditControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$profileEditControllerHash();

  @$internal
  @override
  ProfileEditController create() => ProfileEditController();
}

String _$profileEditControllerHash() =>
    r'862abf944db0f21492fb563ea4b055f46b81333d';

abstract class _$ProfileEditController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<void>, void>,
        AsyncValue<void>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
