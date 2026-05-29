// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_success_snackbar_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One-time flag — Sign-in screen reads it and clears it after showing
/// the "Your account has been deleted." snackbar.

@ProviderFor(DeleteSuccessSnackbar)
final deleteSuccessSnackbarProvider = DeleteSuccessSnackbarProvider._();

/// One-time flag — Sign-in screen reads it and clears it after showing
/// the "Your account has been deleted." snackbar.
final class DeleteSuccessSnackbarProvider
    extends $NotifierProvider<DeleteSuccessSnackbar, bool> {
  /// One-time flag — Sign-in screen reads it and clears it after showing
  /// the "Your account has been deleted." snackbar.
  DeleteSuccessSnackbarProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'deleteSuccessSnackbarProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$deleteSuccessSnackbarHash();

  @$internal
  @override
  DeleteSuccessSnackbar create() => DeleteSuccessSnackbar();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$deleteSuccessSnackbarHash() =>
    r'6b409a33b03908f858e8be16b4d04660a0ce54d7';

/// One-time flag — Sign-in screen reads it and clears it after showing
/// the "Your account has been deleted." snackbar.

abstract class _$DeleteSuccessSnackbar extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
