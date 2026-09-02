import 'package:jobify_app/data/feed/feed_dto.dart';
import 'package:jobify_app/data/feed/feed_repository_impl.dart';
import 'package:jobify_app/data/feed/match_feedback_rating.dart';
import 'package:jobify_app/data/jobs/jobs_repository_impl.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';
import 'package:jobify_app/presentation/paging/paged_state.dart';
import 'package:jobify_app/presentation/paging/paging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_controller.g.dart';

typedef FeedState = PagedState<FeedItemDto>;

@riverpod
class FeedController extends _$FeedController {
  /// Bumped on every [build] — every filter change and every [refresh].
  ///
  /// Riverpod re-executes `build()` on the SAME notifier instance when a
  /// watched dependency changes, so this survives across rebuilds and is what
  /// makes it a usable staleness token.
  int _generation = 0;

  @override
  Future<FeedState> build() async {
    _generation++;
    final filters = ref.watch(feedFiltersControllerProvider);
    final page = await ref
        .read(feedRepositoryProvider)
        .fetchPage(filters: filters.isEmpty ? null : filters);
    return PagedState(
      items: page.items,
      cursor: page.nextCursor,
      hasMore: page.nextCursor != null,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() {
    // Snapshot the GENERATION this call started under, not the filter value.
    //
    // If filters change mid-flight (user edits them while a page-2 fetch is in
    // the air), the fetch that started under the old filters must not land on
    // top of the rebuild that change already triggered — `build()` watches the
    // filters provider and replaces `state` wholesale, so a stale `setState`
    // here would silently merge old-filter jobs into the new result.
    //
    // Comparing filter VALUES could not detect this: `FeedFilters` is
    // @freezed, so an A→B→A toggle within one fetch's flight produces an
    // object that compares EQUAL to the snapshot even though two rebuilds
    // have happened and page 1 has already been replaced. A counter is
    // monotonic, so it catches the round trip that equality cannot.
    final generationAtStart = _generation;
    return loadNextPage<FeedItemDto>(
      currentState: state,
      fetch: ({String? cursor}) async {
        final filters = ref.read(feedFiltersControllerProvider);
        final page = await ref
            .read(feedRepositoryProvider)
            .fetchPage(
              cursor: cursor,
              filters: filters.isEmpty ? null : filters,
            );
        return PagedState(
          items: page.items,
          cursor: page.nextCursor,
          hasMore: page.nextCursor != null,
        );
      },
      setState: (s) {
        if (_generation != generationAtStart) return;
        state = s;
      },
    );
  }

  /// Optimistic thumbs-down: remove the card immediately, roll back on error.
  Future<void> rateDown(String jobId) async {
    final prev = state;
    final s = state.value;
    if (s != null) {
      state = AsyncData(
        s.copyWith(
          items: [
            for (final it in s.items)
              if (it.job.id != jobId) it,
          ],
        ),
      );
    }
    try {
      await ref
          .read(jobsRepositoryProvider)
          .rateMatch(jobId, MatchFeedbackRating.down);
    } catch (_) {
      state = prev; // restore — the card comes back
      rethrow;
    }
  }

  /// Thumbs-up: persist, then patch the item in place (card stays).
  Future<void> rateUp(String jobId) async {
    await ref
        .read(jobsRepositoryProvider)
        .rateMatch(jobId, MatchFeedbackRating.up);
    final s = state.value;
    if (s == null) return;
    state = AsyncData(
      s.copyWith(
        items: [
          for (final it in s.items)
            if (it.job.id != jobId)
              it
            else
              FeedItemDto(
                match: MatchSummaryDto(
                  id: it.match.id,
                  totalScore: it.match.totalScore,
                  scoreComponents: it.match.scoreComponents,
                  explanation: it.match.explanation,
                  surfacedAt: it.match.surfacedAt,
                  myFeedback: MatchFeedbackRating.up,
                ),
                job: it.job,
                employer: it.employer,
              ),
        ],
      ),
    );
  }

  /// Undo a thumbs-down: clear the rating server-side, refetch page 1.
  Future<void> undoDown(String jobId) async {
    await ref.read(jobsRepositoryProvider).clearMatchFeedback(jobId);
    await refresh();
  }
}
