import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_filters.freezed.dart';

/// Ephemeral applicant feed filters — query params only, never persisted.
/// [minCtc] is absolute rupees (the UI converts from lakhs).
@freezed
abstract class FeedFilters with _$FeedFilters {
  const factory FeedFilters({
    String? query,
    @Default(<String>[]) List<String> locations,
    int? minYears,
    double? minCtc,
  }) = _FeedFilters;

  const FeedFilters._();

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) &&
      locations.isEmpty &&
      minYears == null &&
      minCtc == null;

  /// Dio's default ListFormat.multi serializes the list value as repeated
  /// `location=` params, matching the backend's `list[str]` Query.
  Map<String, dynamic> toQueryParameters() => {
        if (query != null && query!.trim().isNotEmpty) 'q': query!.trim(),
        if (locations.isNotEmpty) 'location': locations,
        if (minYears != null) 'min_years': minYears,
        if (minCtc != null) 'min_ctc': minCtc,
      };
}
