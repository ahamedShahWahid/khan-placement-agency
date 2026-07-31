import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
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
                decoration: const InputDecoration(
                  hintText: 'Search title or company',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: JobifySpacing.sm),
            IconButton(
              tooltip: 'Filters',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const FeedFilterSheet(),
              ),
              icon: Icon(
                Icons.tune,
                color: filters.isEmpty
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
                  onDeleted: () => notifier.set(filters.copyWith(
                    locations: [
                      for (final l in filters.locations)
                        if (l != loc) l,
                    ],
                  )),
                ),
              if (filters.minYears != null)
                InputChip(
                  label: Text('${filters.minYears} yrs'),
                  onDeleted: () =>
                      notifier.set(filters.copyWith(minYears: null)),
                ),
              if (filters.minCtc != null)
                InputChip(
                  label: Text(
                      '≥ ₹${(filters.minCtc! / 100000).toStringAsFixed(filters.minCtc! % 100000 == 0 ? 0 : 1)}L'),
                  onDeleted: () => notifier.set(filters.copyWith(minCtc: null)),
                ),
              ActionChip(
                label: const Text('Clear all'),
                onPressed: () {
                  _searchController.clear();
                  notifier.clear();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
