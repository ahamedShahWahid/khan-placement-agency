// Hindi-locale rendering smoke tests (Task 9, hindi-i18n).
//
// Pumps Feed (empty state), Profile, and Applications with
// `locale: const Locale('hi')` set directly on the harness `MaterialApp` —
// this is what actually selects the ARB translation set (independent of
// `localeControllerProvider`, which only drives the *real* app's runtime
// language switcher). Each test asserts a known Devanagari string renders
// and that the widget tree doesn't throw, proving the longer Hindi copy
// doesn't break layout and that no locale-lookup/missing-glyph exception
// surfaces during layout+paint.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_dto.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/data/feed/feed_repository.dart';
import 'package:jobify_app/data/feed/feed_repository_impl.dart';
import 'package:jobify_app/data/jobs/applications_repository.dart';
import 'package:jobify_app/data/jobs/applications_repository_impl.dart';
import 'package:jobify_app/data/jobs/jobs_dto.dart';
import 'package:jobify_app/data/jobs/saved_jobs_repository.dart';
import 'package:jobify_app/data/jobs/saved_jobs_repository_impl.dart';
import 'package:jobify_app/data/me/me_dto.dart';
import 'package:jobify_app/data/me/me_repository.dart';
import 'package:jobify_app/data/me/me_repository_impl.dart';
import 'package:jobify_app/data/me/profile_update_dto.dart';
import 'package:jobify_app/data/preferences/desired_role.dart';
import 'package:jobify_app/data/preferences/preferences_dto.dart';
import 'package:jobify_app/data/preferences/preferences_repository.dart';
import 'package:jobify_app/data/preferences/preferences_repository_impl.dart';
import 'package:jobify_app/data/preferences/preferences_update_dto.dart';
import 'package:jobify_app/data/resume/resume_dto.dart';
import 'package:jobify_app/data/resume/resume_repository.dart';
import 'package:jobify_app/data/resume/resume_repository_impl.dart';
import 'package:jobify_app/l10n/app_localizations.dart';
import 'package:jobify_app/presentation/applications/applications_screen.dart';
import 'package:jobify_app/presentation/feed/feed_screen.dart';
import 'package:jobify_app/presentation/profile/package_info_provider.dart';
import 'package:jobify_app/presentation/profile/profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/src/framework.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFeedRepo implements FeedRepository {
  _FakeFeedRepo(this.page);
  final FeedPageDto page;
  @override
  Future<FeedPageDto> fetchPage({
    String? cursor,
    int limit = 20,
    FeedFilters? filters,
  }) async => page;
}

class _FakeResumeRepo implements ResumeRepository {
  @override
  Future<ResumeDto?> current() async => null;
  @override
  Future<ResumeDto> upload({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async => throw UnimplementedError();
}

class _FakePrefsRepo implements PreferencesRepository {
  @override
  Future<PreferencesDto> fetch() async => const PreferencesDto(
    desiredRole: DesiredRole.softwareEngineering,
    locations: ['Pune'],
    expectedCtc: '1800000.00',
  );
  @override
  Future<PreferencesDto> update(PreferencesUpdateDto update) async => fetch();
}

class _FakeApplicationsRepo implements ApplicationsRepository {
  @override
  Future<ApplicationsPageDto> fetchPage({
    String? cursor,
    int limit = 20,
  }) async => const ApplicationsPageDto(items: []);
  @override
  Future<ApplicationDto> withdraw(String applicationId) async =>
      throw UnimplementedError();
  @override
  Future<List<StageEventDto>> fetchTimeline(String applicationId) async =>
      throw UnimplementedError();
}

class _FakeSavedJobsRepo implements SavedJobsRepository {
  @override
  Future<SavedJobsPageDto> fetchPage({String? cursor, int limit = 20}) async =>
      const SavedJobsPageDto(items: []);
}

class _FakeMeRepo implements MeRepository {
  @override
  Future<MeDto> fetch() async => const MeDto(
    id: 'u1',
    email: 'eng@example.com',
    displayName: 'Eng U',
    role: 'applicant',
    applicant: ApplicantSummaryDto(id: 'a1', fullName: 'Eng U'),
  );
  @override
  Future<MeDto> updateProfile(ProfileUpdateDto update) async => fetch();
}

Widget _wrap(Widget child, {required List<Override> overrides}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('hi'),
        theme: ThemeData.light(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Feed empty state renders Hindi copy without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FeedScreen(),
        overrides: [
          feedRepositoryProvider.overrideWithValue(
            _FakeFeedRepo(const FeedPageDto(items: [])),
          ),
          resumeRepositoryProvider.overrideWithValue(_FakeResumeRepo()),
          preferencesRepositoryProvider.overrideWithValue(_FakePrefsRepo()),
          applicationsRepositoryProvider.overrideWithValue(
            _FakeApplicationsRepo(),
          ),
          savedJobsRepositoryProvider.overrideWithValue(_FakeSavedJobsRepo()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('हम अभी भी आपके लिए मैच ढूंढ रहे हैं'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile renders Hindi copy without throwing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ProfileScreen(),
        overrides: [
          meRepositoryProvider.overrideWithValue(_FakeMeRepo()),
          preferencesRepositoryProvider.overrideWithValue(_FakePrefsRepo()),
          packageInfoProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'Jobify',
              packageName: 'com.jobify.app',
              version: '1.0.0',
              buildNumber: '1',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('प्रोफ़ाइल'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Applications empty state renders Hindi copy without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ApplicationsScreen(),
        overrides: [
          applicationsRepositoryProvider.overrideWithValue(
            _FakeApplicationsRepo(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('अभी तक कोई आवेदन नहीं'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
