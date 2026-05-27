import 'package:freezed_annotation/freezed_annotation.dart';

part 'paged_state.freezed.dart';

@freezed
abstract class PagedState<T> with _$PagedState<T> {
  const factory PagedState({
    required List<T> items,
    required String? cursor,
    required bool hasMore,
    @Default(false) bool isLoadingMore,
  }) = _PagedState<T>;
}
