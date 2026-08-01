// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_filters_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Ephemeral, session-scoped filter state. Deliberately autoDispose: it lives
/// exactly as long as the applicant shell (FeedScreen watches FeedController,
/// which watches this) and resets on sign-out for free.

@ProviderFor(FeedFiltersController)
final feedFiltersControllerProvider = FeedFiltersControllerProvider._();

/// Ephemeral, session-scoped filter state. Deliberately autoDispose: it lives
/// exactly as long as the applicant shell (FeedScreen watches FeedController,
/// which watches this) and resets on sign-out for free.
final class FeedFiltersControllerProvider
    extends $NotifierProvider<FeedFiltersController, FeedFilters> {
  /// Ephemeral, session-scoped filter state. Deliberately autoDispose: it lives
  /// exactly as long as the applicant shell (FeedScreen watches FeedController,
  /// which watches this) and resets on sign-out for free.
  FeedFiltersControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'feedFiltersControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$feedFiltersControllerHash();

  @$internal
  @override
  FeedFiltersController create() => FeedFiltersController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedFilters value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedFilters>(value),
    );
  }
}

String _$feedFiltersControllerHash() =>
    r'fb629116535c0737a77ad31ae44fcbb53287943f';

/// Ephemeral, session-scoped filter state. Deliberately autoDispose: it lives
/// exactly as long as the applicant shell (FeedScreen watches FeedController,
/// which watches this) and resets on sign-out for free.

abstract class _$FeedFiltersController extends $Notifier<FeedFilters> {
  FeedFilters build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FeedFilters, FeedFilters>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<FeedFilters, FeedFilters>, FeedFilters, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
