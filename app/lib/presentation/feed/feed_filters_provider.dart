import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_filters_provider.g.dart';

/// Ephemeral, session-scoped filter state. Deliberately autoDispose: it lives
/// exactly as long as the applicant shell (FeedScreen watches FeedController,
/// which watches this) and resets on sign-out for free.
@riverpod
class FeedFiltersController extends _$FeedFiltersController {
  @override
  FeedFilters build() => const FeedFilters();

  // ignore: use_setters_to_change_properties — Riverpod controller pattern
  void set(FeedFilters filters) => state = filters;

  void clear() => state = const FeedFilters();
}
