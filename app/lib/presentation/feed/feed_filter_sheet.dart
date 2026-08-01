import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';

const _presetCities = [
  'Bangalore',
  'Mumbai',
  'Delhi NCR',
  'Hyderabad',
  'Chennai',
  'Pune',
  'Remote',
];

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
          Text('Filter matches', style: theme.textTheme.titleMedium),
          const SizedBox(height: JobifySpacing.lg),
          Text('Location', style: theme.textTheme.labelLarge),
          const SizedBox(height: JobifySpacing.sm),
          Wrap(
            spacing: JobifySpacing.sm,
            runSpacing: JobifySpacing.sm,
            children: [
              for (final city in {..._presetCities, ..._locations})
                FilterChip(
                  label: Text(city),
                  selected: _locations.contains(city),
                  onSelected: (sel) => _toggleCity(city, sel),
                ),
            ],
          ),
          const SizedBox(height: JobifySpacing.sm),
          TextField(
            controller: _customCityController,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: 'Add another city',
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
          Text('Experience', style: theme.textTheme.labelLarge),
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
              Text(_minYears == null ? 'Any' : '$_minYears yrs'),
              IconButton(
                onPressed: () =>
                    setState(() => _minYears = (_minYears ?? -1) + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: JobifySpacing.lg),
          Text('Minimum CTC (lakhs)', style: theme.textTheme.labelLarge),
          const SizedBox(height: JobifySpacing.sm),
          TextField(
            controller: _ctcLakhController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              suffixText: 'L',
              hintText: 'e.g. 5',
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
                child: const Text('Reset'),
              ),
              const SizedBox(width: JobifySpacing.sm),
              FilledButton(onPressed: _apply, child: const Text('Apply')),
            ],
          ),
        ],
      ),
    );
  }
}
