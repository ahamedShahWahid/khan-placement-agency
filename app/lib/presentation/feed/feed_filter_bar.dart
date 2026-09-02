import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filter_sheet.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';

/// Search field + filter button + active-filter chips under the feed summary.
class FeedFilterBar extends ConsumerStatefulWidget {
  const FeedFilterBar({super.key});

  @override
  ConsumerState<FeedFilterBar> createState() => _FeedFilterBarState();
}

class _FeedFilterBarState extends ConsumerState<FeedFilterBar> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Set immediately before any of THIS WIDGET'S OWN calls into the notifier
  /// (a chip's `onDeleted`, "Clear all"), then consumed (read + reset) by
  /// `_syncControllerFromExternalClear` on the resulting notification.
  ///
  /// Needed because value-based heuristics can't distinguish "the user
  /// removed the one-and-only active chip" from "an external caller cleared
  /// everything" — both produce the exact same (previous, next) pair
  /// (active → fully empty). Only the CALL SITE knows which one happened,
  /// so the call site marks it explicitly rather than the listener guessing.
  bool _selfMutation = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final current = ref.read(feedFiltersControllerProvider);
      ref
          .read(feedFiltersControllerProvider.notifier)
          .set(current.copyWith(query: value.trim().isEmpty ? null : value));
    });
  }

  /// Keeps the search field (AND its pending debounce) in sync with an
  /// EXTERNAL clear of the filters — the filtered empty state's "Clear
  /// filters" button, "Clear all", or the filter sheet's Reset — all of
  /// which mutate the provider directly with no reference to this widget's
  /// private [_searchController] or [_debounce].
  ///
  /// Gates on an actual TRANSITION, never merely "next.query is null" (that
  /// would fire on any unrelated mutation — e.g. removing one of several
  /// location chips — and wipe text the user is still typing). Two
  /// transitions both count as "externally cleared":
  ///  - the committed `query` itself went from non-empty to null/empty
  ///    (editing an existing committed search term, cleared mid-edit); or
  ///  - the filters as a whole went from active to fully empty. This
  ///    second check is required because the realistic path to an external
  ///    clear is usually a DIFFERENT filter being active (that's what makes
  ///    the Clear affordance visible in the first place) while the query
  ///    itself was never committed yet — in that case `previous.query` and
  ///    `next.query` are both already null, so a query-only transition
  ///    check would miss it and let the pending debounce silently reinstate
  ///    the query the user just tried to clear.
  ///
  /// A mutation that leaves at least one OTHER filter still active (e.g.
  /// removing one of several chips, or adding a new one) matches neither
  /// condition, so an in-flight debounce is left completely alone —
  /// preserving both the on-screen text and the eventual commit.
  ///
  /// Structural guard first: any notifier call THIS WIDGET made itself
  /// (chip removal, "Clear all") is skipped unconditionally, regardless of
  /// what the resulting (previous, next) pair looks like — see
  /// [_selfMutation]'s doc for why value-based gating alone can't cover
  /// the "removed the last active chip" case.
  void _syncControllerFromExternalClear(
    FeedFilters? previous,
    FeedFilters next,
  ) {
    if (_selfMutation) {
      _selfMutation = false;
      return;
    }

    final previousQuery = previous?.query;
    final queryWasCommitted = previousQuery != null && previousQuery.isNotEmpty;
    final queryNowCleared = next.query == null || next.query!.isEmpty;
    final queryTransitionCleared = queryWasCommitted && queryNowCleared;

    final wasActive = previous != null && !previous.isEmpty;
    final fullReset = wasActive && next.isEmpty;

    if ((queryTransitionCleared || fullReset) &&
        _searchController.text.isNotEmpty) {
      _debounce?.cancel();
      _searchController.clear();
    }
  }

  /// Wraps an in-widget notifier mutation (chip removal, "Clear all") so
  /// the resulting provider notification is recognized as self-inflicted,
  /// not an external clear — see [_selfMutation].
  ///
  /// The listener normally consumes-and-resets the flag itself when the
  /// mutation actually changes the provider's state (Riverpod only notifies
  /// on `previous != next`, so the listener runs synchronously inside
  /// `action()`). But if the mutation happens to produce an EQUAL state
  /// (a no-op set), no notification fires, the listener never runs, and
  /// `_selfMutation` would stay stuck `true` — silently swallowing the
  /// next genuine external clear. Resetting it here unconditionally after
  /// `action()` returns guarantees it can never outlive its own mutation.
  void _mutateSelf(void Function() action) {
    _selfMutation = true;
    action();
    _selfMutation = false;
  }

  Widget _buildCtcChip({
    required FeedFilters filters,
    required FeedFiltersController notifier,
  }) {
    final decimals = filters.minCtc! % 100000 == 0 ? 0 : 1;
    final amount = (filters.minCtc! / 100000).toStringAsFixed(decimals);
    return InputChip(
      label: Text(context.l10n.feedMinCtcChipLabel(amount)),
      onDeleted:
          () => _mutateSelf(() => notifier.set(filters.copyWith(minCtc: null))),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FeedFilters>(
      feedFiltersControllerProvider,
      _syncControllerFromExternalClear,
    );
    final filters = ref.watch(feedFiltersControllerProvider);
    final notifier = ref.read(feedFiltersControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: context.l10n.feedSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: JobifySpacing.sm),
            IconButton(
              tooltip: context.l10n.feedFiltersTooltip,
              onPressed:
                  () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const FeedFilterSheet(),
                  ),
              icon: Icon(
                Icons.tune,
                color:
                    filters.isEmpty
                        ? null
                        : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        if (!filters.isEmpty) ...[
          const SizedBox(height: JobifySpacing.sm),
          Wrap(
            spacing: JobifySpacing.sm,
            runSpacing: JobifySpacing.sm,
            children: [
              for (final loc in filters.locations)
                InputChip(
                  label: Text(loc),
                  onDeleted:
                      () => _mutateSelf(
                        () => notifier.set(
                          filters.copyWith(
                            locations: [
                              for (final l in filters.locations)
                                if (l != loc) l,
                            ],
                          ),
                        ),
                      ),
                ),
              if (filters.minYears != null)
                InputChip(
                  label: Text(context.l10n.feedYearsSuffix(filters.minYears!)),
                  onDeleted:
                      () => _mutateSelf(
                        () => notifier.set(filters.copyWith(minYears: null)),
                      ),
                ),
              if (filters.minCtc != null) ...[
                _buildCtcChip(filters: filters, notifier: notifier),
              ],
              ActionChip(
                label: Text(context.l10n.feedClearAllButton),
                onPressed:
                    () => _mutateSelf(() {
                      // Cancel HERE, not in the listener: this is a self-
                      // mutation, so `_syncControllerFromExternalClear` short-
                      // circuits on `_selfMutation` and never reaches its
                      // `_debounce?.cancel()`. And `_searchController.clear()`
                      // does not fire `onChanged`, so nothing else touches the
                      // timer — an in-flight debounce would fire at its
                      // original
                      // deadline and silently reinstate the query the user just
                      // cleared. (Deliberately NOT hoisted into `_mutateSelf`:
                      // chip removals must leave a pending debounce running.)
                      _debounce?.cancel();
                      _searchController.clear();
                      notifier.clear();
                    }),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
