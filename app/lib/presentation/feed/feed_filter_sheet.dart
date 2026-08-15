import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';

/// Upper bound for the experience stepper, mirroring the server's
/// `min_years: Query(None, ge=0, le=80)` on `GET /v1/feed`. Exceeding it is a
/// 422, which surfaces as a full-feed error view rather than a field error —
/// so the client must not be able to produce the value at all.
const int _kMaxMinYears = 80;

/// Bottom sheet editing location / experience / min-CTC. Local draft state;
/// nothing hits the provider until Apply.
class FeedFilterSheet extends ConsumerStatefulWidget {
  const FeedFilterSheet({super.key});

  @override
  ConsumerState<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends ConsumerState<FeedFilterSheet> {
  late List<String> _locations;
  int? _minYears;
  late final TextEditingController _ctcLakhController;
  final _customCityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = ref.read(feedFiltersControllerProvider);
    _locations = [...f.locations];
    _minYears = f.minYears;
    _ctcLakhController = TextEditingController(
      text: f.minCtc == null ? '' : (f.minCtc! / 100000).toString(),
    );
  }

  @override
  void dispose() {
    _ctcLakhController.dispose();
    _customCityController.dispose();
    super.dispose();
  }

  /// Preset city options, keyed by their CANONICAL (always-English) wire
  /// value — the value stored in [_locations] and sent to the backend's
  /// location filter, which matches against employer-authored job location
  /// strings. Only the display label is localized (`feedCityRemote` is the
  /// one entry whose Hindi rendering actually differs from the English
  /// value); the map keys must never change with locale.
  Map<String, String> _presetCityLabels(BuildContext context) {
    final l10n = context.l10n;
    return {
      'Bangalore': l10n.feedCityBangalore,
      'Mumbai': l10n.feedCityMumbai,
      'Delhi NCR': l10n.feedCityDelhiNcr,
      'Hyderabad': l10n.feedCityHyderabad,
      'Chennai': l10n.feedCityChennai,
      'Pune': l10n.feedCityPune,
      'Remote': l10n.feedCityRemote,
    };
  }

  void _toggleCity(String city, bool selected) {
    setState(() {
      if (selected) {
        if (!_locations.contains(city)) _locations.add(city);
      } else {
        _locations.remove(city);
      }
    });
  }

  void _apply() {
    final current = ref.read(feedFiltersControllerProvider);
    final lakh = double.tryParse(_ctcLakhController.text.trim());
    ref.read(feedFiltersControllerProvider.notifier).set(
          FeedFilters(
            query: current.query,
            locations: _locations,
            minYears: _minYears,
            minCtc: lakh == null || lakh <= 0 ? null : lakh * 100000,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final presetLabels = _presetCityLabels(context);
    return Padding(
      padding: EdgeInsets.only(
        left: JobifySpacing.lg,
        right: JobifySpacing.lg,
        top: JobifySpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + JobifySpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.feedFilterSheetTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: JobifySpacing.lg),
          Text(l10n.feedFilterLocationLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: JobifySpacing.sm),
          Wrap(
            spacing: JobifySpacing.sm,
            runSpacing: JobifySpacing.sm,
            children: [
              for (final city in {...presetLabels.keys, ..._locations})
                FilterChip(
                  label: Text(presetLabels[city] ?? city),
                  selected: _locations.contains(city),
                  onSelected: (sel) => _toggleCity(city, sel),
                ),
            ],
          ),
          const SizedBox(height: JobifySpacing.sm),
          TextField(
            controller: _customCityController,
            maxLength: 100,
            decoration: InputDecoration(
              hintText: l10n.feedFilterAddCityHint,
              isDense: true,
              counterText: '',
            ),
            onSubmitted: (v) {
              final city = v.trim();
              if (city.isNotEmpty) _toggleCity(city, true);
              _customCityController.clear();
            },
          ),
          const SizedBox(height: JobifySpacing.lg),
          Text(
            l10n.feedFilterExperienceLabel,
            style: theme.textTheme.labelLarge,
          ),
          Row(
            children: [
              IconButton(
                onPressed: _minYears == null
                    ? null
                    : () => setState(
                          () => _minYears =
                              _minYears! > 0 ? _minYears! - 1 : null,
                        ),
                icon: const Icon(Icons.remove),
              ),
              Text(
                _minYears == null
                    ? l10n.feedFilterExperienceAny
                    : l10n.feedYearsSuffix(_minYears!),
              ),
              IconButton(
                // Disabled at the ceiling rather than silently capping, so the
                // control tells the truth about the bound. `GET /v1/feed`
                // declares `min_years: Query(ge=0, le=80)`, so an unbounded
                // stepper let a determined tap reach 81 and turn the whole
                // feed into an error view on a 422. Keep in lockstep with the
                // route's `le=`.
                onPressed: _minYears != null && _minYears! >= _kMaxMinYears
                    ? null
                    : () => setState(() => _minYears = (_minYears ?? -1) + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: JobifySpacing.lg),
          Text(l10n.feedFilterMinCtcLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: JobifySpacing.sm),
          TextField(
            controller: _ctcLakhController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: l10n.feedFilterCtcPrefix,
              suffixText: l10n.feedFilterCtcSuffix,
              hintText: l10n.feedFilterCtcHint,
              isDense: true,
            ),
          ),
          const SizedBox(height: JobifySpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  final current = ref.read(feedFiltersControllerProvider);
                  ref
                      .read(feedFiltersControllerProvider.notifier)
                      .set(FeedFilters(query: current.query));
                  Navigator.of(context).pop();
                },
                child: Text(l10n.feedFilterResetButton),
              ),
              const SizedBox(width: JobifySpacing.sm),
              FilledButton(
                onPressed: _apply,
                child: Text(l10n.feedFilterApplyButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
