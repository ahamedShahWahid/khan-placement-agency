// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeedController)
final feedControllerProvider = FeedControllerProvider._();

final class FeedControllerProvider
    extends $AsyncNotifierProvider<FeedController, FeedState> {
  FeedControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'feedControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$feedControllerHash();

  @$internal
  @override
  FeedController create() => FeedController();
}

String _$feedControllerHash() => r'043fec172daf1fd3750052d9ea5512c642c6284f';

abstract class _$FeedController extends $AsyncNotifier<FeedState> {
  FutureOr<FeedState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FeedState>, FeedState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<FeedState>, FeedState>,
        AsyncValue<FeedState>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
