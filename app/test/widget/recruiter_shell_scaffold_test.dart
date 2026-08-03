import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobify_app/presentation/routing/locale_controller.dart';
import 'package:jobify_app/presentation/widgets/jobify_recruiter_shell_scaffold.dart';

/// Trivial branch body so this test stays focused on the shell scaffold's
/// tab bar and branch switching — not the real screens' provider wiring
/// (those are exercised in their own widget tests).
class _Stub extends StatelessWidget {
  const _Stub(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/recruiter/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => JobifyRecruiterShellScaffold(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/recruiter/dashboard',
                  builder: (_, __) => const _Stub('DASH BODY'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/recruiter/jobs',
                  builder: (_, __) => const _Stub('JOBS BODY'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/recruiter/employer',
                  builder: (_, __) => const _Stub('EMPLOYER BODY'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/recruiter/profile',
                  builder: (_, __) => const _Stub('PROFILE BODY'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

void main() {
  testWidgets('recruiter shell shows four tabs and switches branches',
      (tester) async {
    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: ThemeData.light(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Employer'), findsOneWidget);
    expect(find.text('DASH BODY'), findsOneWidget);

    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(find.text('JOBS BODY'), findsOneWidget);
  });

  testWidgets(
      'entering the recruiter shell with Locale(hi) already set forces '
      'English (recruiter surfaces are English-only)', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Keep the autoDispose locale provider alive for the test's duration,
    // same as locale_controller_test.dart.
    final sub = container.listen(localeControllerProvider, (_, __) {});
    addTearDown(sub.close);

    // Simulate an hi-applicant who just accepted an employer invite:
    // localeControllerProvider still holds Locale('hi') (it only resets on
    // sign-out/delete-account — see locale_controller.dart) at the moment
    // the role flip lands them in the recruiter shell.
    container.read(localeControllerProvider.notifier).setFromLanguage('hi');
    expect(container.read(localeControllerProvider), const Locale('hi'));

    final router = _buildRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ThemeData.light(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider), const Locale('en'));
  });
}
