import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';

void main() {
  test('defaults empty; set + clear round-trip', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Keep the autoDispose provider alive for the test's duration.
    final sub = c.listen(feedFiltersControllerProvider, (_, __) {});
    addTearDown(sub.close);

    expect(c.read(feedFiltersControllerProvider).isEmpty, isTrue);
    c
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(query: 'flutter', minYears: 3));
    expect(c.read(feedFiltersControllerProvider).query, 'flutter');
    c.read(feedFiltersControllerProvider.notifier).clear();
    expect(c.read(feedFiltersControllerProvider).isEmpty, isTrue);
  });
}
