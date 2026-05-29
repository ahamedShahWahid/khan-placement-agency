// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consents_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(consentsRepository)
final consentsRepositoryProvider = ConsentsRepositoryProvider._();

final class ConsentsRepositoryProvider extends $FunctionalProvider<
    ConsentsRepository,
    ConsentsRepository,
    ConsentsRepository> with $Provider<ConsentsRepository> {
  ConsentsRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'consentsRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$consentsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConsentsRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConsentsRepository create(Ref ref) {
    return consentsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConsentsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConsentsRepository>(value),
    );
  }
}

String _$consentsRepositoryHash() =>
    r'c8344ca580fc509434d298d0c990c493de308420';
