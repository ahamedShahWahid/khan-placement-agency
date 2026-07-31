import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/data/feed/feed_repository.dart';
import 'package:jobify_app/data/feed/feed_repository_impl.dart';
import 'package:jobify_app/data/jobs/applications_repository_impl.dart';
import 'package:jobify_app/data/jobs/saved_jobs_repository_impl.dart';
import 'package:jobify_app/data/preferences/desired_role.dart';
import 'package:jobify_app/data/preferences/preferences_dto.dart';
import 'package:jobify_app/data/preferences/preferences_repository.dart';
import 'package:jobify_app/data/preferences/preferences_repository_impl.dart';
import 'package:jobify_app/data/preferences/preferences_update_dto.dart';
import 'package:jobify_app/data/resume/resume_dto.dart';
import 'package:jobify_app/data/resume/resume_parse_status.dart';
import 'package:jobify_app/data/resume/resume_repository.dart';
import 'package:jobify_app/data/resume/resume_repository_impl.dart';
import 'package:jobify_app/presentation/feed/feed_filter_bar.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';
import 'package:jobify_app/presentation/feed/feed_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_repositories.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );

class _FakeResumeRepo implements ResumeRepository {
  _FakeResumeRepo(this._current);
  final ResumeDto? _current;
  @override
  Future<ResumeDto?> current() async => _current;
  @override
  Future<ResumeDto> upload({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async =>
      throw UnimplementedError();
}

class _FakePrefsRepo implements PreferencesRepository {
  _FakePrefsRepo(this._dto);
  final PreferencesDto _dto;
  @override
  Future<PreferencesDto> fetch() async => _dto;
  @override
  Future<PreferencesDto> update(PreferencesUpdateDto update) async => _dto;
}

final _completeResumeDto = ResumeDto(
  id: 'r1',
  applicantId: 'a1',
  originalFilename: 'cv.pdf',
  contentType: 'application/pdf',
  sizeBytes: 1,
  parseStatus: ResumeParseStatus.parsed,
  createdAt: DateTime(2026),
);

const _completePrefs = PreferencesDto(
  desiredRole: DesiredRole.softwareEngineering,
  locations: ['Pune'],
  expectedCtc: '1800000.00',
);

/// Same override boilerplate `feed_screen_test.dart` uses to make `FeedScreen`
/// (and its `FeedSummaryRow`) renderable without hitting real (dio) repos.
Widget _wrapFeedScreen({required FeedRepository repo}) => ProviderScope(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repo),
        resumeRepositoryProvider
            .overrideWithValue(_FakeResumeRepo(_completeResumeDto)),
        preferencesRepositoryProvider
            .overrideWithValue(_FakePrefsRepo(_completePrefs)),
        applicationsRepositoryProvider
            .overrideWithValue(FakeApplicationsRepository()),
        savedJobsRepositoryProvider
            .overrideWithValue(FakeSavedJobsRepository()),
      ],
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const FeedScreen(),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search field debounces then sets query filter', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    },),),);

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(feedFiltersControllerProvider).query, isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(feedFiltersControllerProvider).query, 'flutter');
  });

  testWidgets('search field clears when the query filter is cleared externally',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    },),),);

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(feedFiltersControllerProvider).query, 'flutter');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'flutter',
    );

    // External clear — e.g. the filtered empty state's "Clear filters"
    // button — has no reference to FeedFilterBar's private controller.
    container.read(feedFiltersControllerProvider.notifier).clear();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
      'external clear cancels the pending debounce — it does not resurrect '
      'the query once the original deadline passes', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    },),),);
    // Seed an active (non-query) filter first — realistically, the Clear
    // affordance that calls `notifier.clear()` externally is only ever
    // visible/tappable when SOME filter is already active; a query that was
    // never committed can't be what makes it visible.
    container
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(locations: ['Pune']));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'flutter');
    // Well inside the 400ms debounce window — nothing committed yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(feedFiltersControllerProvider).query, isNull);

    // External clear races the pending debounce.
    container.read(feedFiltersControllerProvider.notifier).clear();
    await tester.pump();

    // Let the ORIGINAL debounce deadline pass. If the timer wasn't
    // cancelled, it fires here and silently reinstates `query: 'flutter'`.
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(feedFiltersControllerProvider).query, isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
      'an unrelated external mutation while typing does not wipe the '
      'pending search text', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    },),),);

    await tester.enterText(find.byType(TextField), 'flutter');
    // Well inside the 400ms debounce window — nothing committed yet.
    await tester.pump(const Duration(milliseconds: 100));

    // Externally set a locations-only filter (query stays null) — e.g. the
    // filter sheet's Apply, unrelated to the in-flight search text.
    container
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(locations: ['Pune']));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'flutter',
    );

    // Let the debounce complete — the typed text must still land.
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(feedFiltersControllerProvider).query, 'flutter');
  });

  testWidgets(
      'removing the last active chip while typing does not wipe the '
      'pending search text (structurally identical to an external clear)',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    },),),);
    // Exactly ONE active (non-query) filter — removing it below produces
    // previous.isEmpty=false -> next.isEmpty=true, the SAME (previous, next)
    // shape an external `notifier.clear()` would produce. Only the call
    // site (in-widget chip vs. an external caller) can tell them apart.
    container
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(locations: ['Pune']));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'flutter');
    // Well inside the 400ms debounce window — nothing committed yet.
    await tester.pump(const Duration(milliseconds: 100));

    // The chip's own in-widget onDeleted — not an external caller.
    tester
        .widget<InputChip>(find.widgetWithText(InputChip, 'Pune'))
        .onDeleted!();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'flutter',
    );
    expect(container.read(feedFiltersControllerProvider).locations, isEmpty);

    // Let the debounce complete — the typed text must still land.
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(feedFiltersControllerProvider).query, 'flutter');
  });

  testWidgets(
      '"Clear all" cancels the pending debounce — it does not resurrect the '
      'query once the original deadline passes', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    },),),);
    // "Clear all" is an in-widget mutation, so the listener short-circuits on
    // `_selfMutation` and never reaches the value-based cancel branch — this
    // call site must cancel the debounce itself. Seed a filter so the chip
    // row (and therefore "Clear all") renders at all.
    container
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(locations: ['Pune']));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'flutter');
    // Well inside the 400ms debounce window — nothing committed yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(feedFiltersControllerProvider).query, isNull);

    await tester.tap(find.widgetWithText(ActionChip, 'Clear all'));
    await tester.pump();

    // Let the ORIGINAL debounce deadline pass. If the timer wasn't
    // cancelled, it fires here and silently reinstates `query: 'flutter'`
    // even though the field (and every chip) reads as cleared.
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(feedFiltersControllerProvider).query, isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('active filters render chips; clearing a chip removes it',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    },),),);
    container
        .read(feedFiltersControllerProvider.notifier)
        .set(const FeedFilters(locations: ['Pune'], minYears: 3));
    await tester.pump();

    expect(find.text('Pune'), findsOneWidget);
    expect(find.text('3 yrs'), findsOneWidget);

    // Invoke onDeleted directly — the default delete-icon glyph differs
    // between Material versions, so tapping by icon is fragile.
    tester
        .widget<InputChip>(find.widgetWithText(InputChip, 'Pune'))
        .onDeleted!();
    await tester.pump();
    expect(container.read(feedFiltersControllerProvider).locations, isEmpty);
    expect(container.read(feedFiltersControllerProvider).minYears, 3);
  });

  testWidgets(
      'filtered empty state shows Nothing matches your filters and clears',
      (tester) async {
    final fakeRepo = FakeFeedRepository(items: const []);
    await tester.pumpWidget(_wrapFeedScreen(repo: fakeRepo));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FeedScreen)),
    );
    container.read(feedFiltersControllerProvider.notifier).set(
          const FeedFilters(locations: ['Pune']),
        );
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches your filters'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(container.read(feedFiltersControllerProvider).isEmpty, isTrue);
  });
}
