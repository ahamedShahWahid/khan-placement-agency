import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_dto.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/data/feed/feed_repository.dart';
import 'package:jobify_app/data/feed/feed_repository_impl.dart';
import 'package:jobify_app/data/jobs/job_status.dart';
import 'package:jobify_app/presentation/feed/feed_controller.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';

/// Fake repo whose SECOND `fetchPage` call (the loadMore page-2 fetch under
/// filters A) hangs on an externally-controlled [Completer], so a test can
/// change filters while it's in flight and then resolve it afterward.
class _SlowLoadMoreFeedRepo implements FeedRepository {
  int call = 0;
  Completer<FeedPageDto>? pendingCompleter;

  @override
  Future<FeedPageDto> fetchPage({
    String? cursor,
    int limit = 20,
    FeedFilters? filters,
  }) {
    call++;
    switch (call) {
      case 1:
        // Initial build under filters A (empty).
        return Future.value(
          FeedPageDto(items: [_item('a1')], nextCursor: 'cA1'),
        );
      case 2:
        // loadMore's page-2 fetch, still under filters A — held open.
        pendingCompleter = Completer<FeedPageDto>();
        return pendingCompleter!.future;
      default:
        // Rebuild triggered by the filter change to B.
        return Future.value(FeedPageDto(items: [_item('b1')]));
    }
  }
}

class _FakeFeedRepo implements FeedRepository {
  _FakeFeedRepo(this.pages);
  final List<FeedPageDto> pages;
  int call = 0;
  final List<FeedFilters?> receivedFilters = [];
  final List<String?> receivedCursors = [];
  @override
  Future<FeedPageDto> fetchPage({
    String? cursor,
    int limit = 20,
    FeedFilters? filters,
  }) async {
    receivedFilters.add(filters);
    receivedCursors.add(cursor);
    return pages[call++];
  }
}

FeedItemDto _item(String jobId) => FeedItemDto(
  match: MatchSummaryDto(
    id: 'm-$jobId',
    totalScore: 0.8,
    scoreComponents: const {},
  ),
  job: JobSummaryDto(
    id: jobId,
    title: 'T-$jobId',
    locations: const ['BLR'],
    status: JobStatus.open,
    postedAt: DateTime.parse('2026-05-18T00:00:00Z'),
  ),
  employer: const EmployerSummaryDto(id: 'e1', name: 'Acme'),
);

void main() {
  test(
    'initial build returns first page; hasMore tracks next_cursor',
    () async {
      final c = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(
            _FakeFeedRepo([
              FeedPageDto(items: [_item('j1'), _item('j2')], nextCursor: 'c1'),
            ]),
          ),
        ],
      );
      final s = await c.read(feedControllerProvider.future);
      expect(s.items, hasLength(2));
      expect(s.hasMore, isTrue);
      expect(s.cursor, 'c1');
    },
  );

  test('loadMore appends items + updates cursor + flips hasMore', () async {
    final c = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          _FakeFeedRepo([
            FeedPageDto(items: [_item('j1')], nextCursor: 'c1'),
            FeedPageDto(items: [_item('j2'), _item('j3')]),
          ]),
        ),
      ],
    );
    await c.read(feedControllerProvider.future);
    await c.read(feedControllerProvider.notifier).loadMore();
    final s = c.read(feedControllerProvider).value!;
    expect(s.items, hasLength(3));
    expect(s.hasMore, isFalse);
  });

  test('loadMore is a no-op when hasMore=false', () async {
    final c = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          _FakeFeedRepo([
            FeedPageDto(items: [_item('j1')]),
          ]),
        ),
      ],
    );
    await c.read(feedControllerProvider.future);
    await c.read(feedControllerProvider.notifier).loadMore();
    expect(c.read(feedControllerProvider).value!.items, hasLength(1));
  });

  test(
    'filter change rebuilds feed from page 1 with filters applied',
    () async {
      final repo = _FakeFeedRepo([
        FeedPageDto(items: [_item('j1')], nextCursor: 'c1'),
        FeedPageDto(items: [_item('j2')]),
      ]);
      final c = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(feedControllerProvider, (_, __) {});
      addTearDown(sub.close);

      await c.read(feedControllerProvider.future);
      expect(repo.receivedFilters, [null]); // empty filters sent as null

      c
          .read(feedFiltersControllerProvider.notifier)
          .set(const FeedFilters(locations: ['Pune']));
      final s = await c.read(feedControllerProvider.future);

      expect(s.items.single.job.id, 'j2');
      expect(repo.receivedCursors.last, isNull); // reset to page 1
      expect(repo.receivedFilters.last, const FeedFilters(locations: ['Pune']));
    },
  );

  test('loadMore carries the active filters', () async {
    final repo = _FakeFeedRepo([
      FeedPageDto(items: [_item('j1')], nextCursor: 'c1'),
      FeedPageDto(items: [_item('j2')]),
    ]);
    final c = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);

    c
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(query: 'x'));
    await c.read(feedControllerProvider.future);
    await c.read(feedControllerProvider.notifier).loadMore();

    expect(repo.receivedCursors.last, 'c1');
    expect(repo.receivedFilters.last, const FeedFilters(query: 'x'));
  });

  test('stale in-flight loadMore fetch is discarded once filters change '
      'mid-flight', () async {
    final repo = _SlowLoadMoreFeedRepo();
    final c = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(feedControllerProvider, (_, __) {});
    addTearDown(sub.close);

    // Initial build under filters A (empty) — one page, more available.
    await c.read(feedControllerProvider.future);
    expect(c.read(feedControllerProvider).value!.items.map((i) => i.job.id), [
      'a1',
    ]);

    // Start loadMore. Its fetch (call #2) hangs on the completer.
    final loadMoreFuture = c.read(feedControllerProvider.notifier).loadMore();
    expect(repo.pendingCompleter, isNotNull);

    // Change filters mid-flight — triggers a rebuild from page 1 under B.
    c
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(locations: ['Pune']));
    final rebuilt = await c.read(feedControllerProvider.future);
    expect(rebuilt.items.map((i) => i.job.id), ['b1']);

    // Now let the stale A page-2 fetch resolve.
    repo.pendingCompleter!.complete(FeedPageDto(items: [_item('a2')]));
    await loadMoreFuture;

    // The filtered rebuild must survive — no merged-in A pages.
    final finalState = c.read(feedControllerProvider).value!;
    expect(finalState.items.map((i) => i.job.id), ['b1']);
  });

  test('stale in-flight loadMore fetch is discarded even when filters return '
      'to their original value (A -> B -> A)', () async {
    // The case a value-equality guard CANNOT catch. `FeedFilters` is @freezed,
    // so after toggling away and back the live filters compare EQUAL to the
    // snapshot taken when loadMore started — the old guard saw "unchanged" and
    // merged the stale page. Two rebuilds have happened by then and page 1 has
    // already been replaced, so the merge duplicated jobs into a list built
    // from a different fetch. A monotonic generation counter sees the round
    // trip that equality erases.
    final repo = _SlowLoadMoreFeedRepo();
    final c = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(feedControllerProvider, (_, __) {});
    addTearDown(sub.close);

    await c.read(feedControllerProvider.future);

    // Start loadMore under filters A; its page-2 fetch hangs.
    final loadMoreFuture = c.read(feedControllerProvider.notifier).loadMore();
    expect(repo.pendingCompleter, isNotNull);

    // A -> B -> A, both within the one fetch's flight. Each `set` must be
    // awaited to completion so that TWO rebuilds actually happen — that is
    // what the generation counter counts.
    c
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(locations: ['Pune']));
    await c.read(feedControllerProvider.future);
    c.read(feedFiltersControllerProvider.notifier).set(const FeedFilters());
    final rebuilt = await c.read(feedControllerProvider.future);

    // Live filters are now value-equal to the snapshot loadMore captured.
    expect(c.read(feedFiltersControllerProvider), const FeedFilters());

    repo.pendingCompleter!.complete(FeedPageDto(items: [_item('a2')]));
    await loadMoreFuture;

    // The latest rebuild must stand alone — the stale page must not append.
    final finalState = c.read(feedControllerProvider).value!;
    expect(finalState.items, rebuilt.items);
    expect(finalState.items.map((i) => i.job.id), isNot(contains('a2')));
  });
}
