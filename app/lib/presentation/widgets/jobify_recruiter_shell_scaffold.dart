import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jobify_app/presentation/routing/locale_controller.dart';

// Recruiter surface — deliberately English-only (spec
// 2026-08-01-hindi-i18n-design.md); Task 9's guard allowlists this file.
class JobifyRecruiterShellScaffold extends ConsumerStatefulWidget {
  const JobifyRecruiterShellScaffold({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<JobifyRecruiterShellScaffold> createState() =>
      _JobifyRecruiterShellScaffoldState();
}

class _JobifyRecruiterShellScaffoldState
    extends ConsumerState<JobifyRecruiterShellScaffold> {
  static const _items = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.work_outline),
      selectedIcon: Icon(Icons.work),
      label: 'Jobs',
    ),
    NavigationDestination(
      icon: Icon(Icons.business_outlined),
      selectedIcon: Icon(Icons.business),
      label: 'Employer',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // The recruiter shell is deliberately English-only (spec
    // 2026-08-01-hindi-i18n-design.md), but localeControllerProvider only
    // resets on sign-out/delete-account — an hi-applicant who accepts an
    // employer invite (invite_response_controller.dart's refreshSession()
    // flips role → roleAwareRedirect lands here) keeps Locale('hi'), so
    // shared localized widgets (AsyncValueWidget/JobifyErrorView) would
    // render Hindi inside this English surface. Force English on every
    // entry into this shell — one structural spot covers every path in
    // (invite accept, employer onboarding, sign-in as an existing
    // recruiter). Deferred a frame since this mutates a provider MaterialApp
    // (an ancestor already built this frame) watches — see sign_in_screen.dart
    // for the same addPostFrameCallback pattern.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(localeControllerProvider.notifier).setFromLanguage('en');
    });
  }

  void _onTap(int i) {
    if (i == widget.shell.currentIndex) {
      widget.shell.goBranch(i, initialLocation: true);
    } else {
      widget.shell.goBranch(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        destinations: _items,
        onDestinationSelected: _onTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: cs.surfaceContainerHighest,
        indicatorColor: cs.primaryContainer,
      ),
    );
  }
}
