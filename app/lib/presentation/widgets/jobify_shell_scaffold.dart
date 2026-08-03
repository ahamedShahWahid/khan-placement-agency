import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/presentation/preferences/preferences_controller.dart';
import 'package:jobify_app/presentation/routing/locale_controller.dart';

class JobifyShellScaffold extends ConsumerStatefulWidget {
  const JobifyShellScaffold({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<JobifyShellScaffold> createState() =>
      _JobifyShellScaffoldState();
}

class _JobifyShellScaffoldState extends ConsumerState<JobifyShellScaffold> {
  @override
  void initState() {
    super.initState();
    // Symmetric case to JobifyRecruiterShellScaffold forcing English: a
    // recruiter->applicant role flip (e.g. leaving the last employer team)
    // re-enters this shell after the recruiter shell forced
    // localeControllerProvider to English. preferencesControllerProvider is
    // keepAlive and only re-fetches on sign-out/delete-account/explicit
    // retry — NOT on a shell switch — so its build() (which sets the locale
    // unconditionally on load, per preferences_controller.dart) won't re-run
    // to restore the applicant's server language. Restore it here from the
    // already-loaded value; if preferences haven't loaded yet, build()'s own
    // unconditional setFromLanguage call covers it once the fetch completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prefs = ref.read(preferencesControllerProvider).value;
      if (prefs != null) {
        ref
            .read(localeControllerProvider.notifier)
            .setFromLanguage(prefs.language);
      }
    });
  }

  List<NavigationDestination> _items(BuildContext context) {
    final l10n = context.l10n;
    return [
      NavigationDestination(
        icon: const Icon(Icons.search),
        label: l10n.shellTabFeed,
      ),
      NavigationDestination(
        icon: const Icon(Icons.bookmark_outline),
        selectedIcon: const Icon(Icons.bookmark),
        label: l10n.shellTabSaved,
      ),
      NavigationDestination(
        icon: const Icon(Icons.assignment_outlined),
        selectedIcon: const Icon(Icons.assignment),
        label: l10n.shellTabApplications,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.shellTabProfile,
      ),
    ];
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
        destinations: _items(context),
        onDestinationSelected: _onTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: cs.surfaceContainerHighest,
        indicatorColor: cs.primaryContainer,
      ),
    );
  }
}
