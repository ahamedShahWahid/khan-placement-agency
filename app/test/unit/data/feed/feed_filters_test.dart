import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';

void main() {
  test('isEmpty: default and whitespace-only query are empty', () {
    expect(const FeedFilters().isEmpty, isTrue);
    expect(const FeedFilters(query: '   ').isEmpty, isTrue);
    expect(const FeedFilters(query: 'x').isEmpty, isFalse);
    expect(const FeedFilters(locations: ['Pune']).isEmpty, isFalse);
    expect(const FeedFilters(minYears: 0).isEmpty, isFalse);
    expect(const FeedFilters(minCtc: 500000).isEmpty, isFalse);
  });

  test('toQueryParameters emits only set keys, trims query', () {
    expect(const FeedFilters().toQueryParameters(), isEmpty);
    expect(
      const FeedFilters(
        query: ' flutter ',
        locations: ['Pune', 'Remote'],
        minYears: 3,
        minCtc: 500000,
      ).toQueryParameters(),
      {
        'q': 'flutter',
        'location': ['Pune', 'Remote'],
        'min_years': 3,
        'min_ctc': 500000.0,
      },
    );
  });

  test('value equality', () {
    expect(
      const FeedFilters(query: 'a', locations: ['P']),
      const FeedFilters(query: 'a', locations: ['P']),
    );
  });
}
