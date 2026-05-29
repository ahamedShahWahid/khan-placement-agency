// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dsr_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dsrRepository)
final dsrRepositoryProvider = DsrRepositoryProvider._();

final class DsrRepositoryProvider
    extends $FunctionalProvider<DsrRepository, DsrRepository, DsrRepository>
    with $Provider<DsrRepository> {
  DsrRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dsrRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dsrRepositoryHash();

  @$internal
  @override
  $ProviderElement<DsrRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DsrRepository create(Ref ref) {
    return dsrRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DsrRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DsrRepository>(value),
    );
  }
}

String _$dsrRepositoryHash() => r'469053719044e3ef09fd3ee966e2741cdad3906e';
