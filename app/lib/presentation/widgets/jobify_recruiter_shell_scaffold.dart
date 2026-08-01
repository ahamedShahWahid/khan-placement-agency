import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:jobify_app/core/l10n/l10n_ext.dart';

class JobifyRecruiterShellScaffold extends StatelessWidget {
  const JobifyRecruiterShellScaffold({required this.shell, super.key});

  final StatefulNavigationShell shell;

  List<NavigationDestination> _items(BuildContext context) {
    final l10n = context.l10n;
    return [
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: l10n.recruiterShellTabDashboard,
      ),
      NavigationDestination(
        icon: const Icon(Icons.work_outline),
        selectedIcon: const Icon(Icons.work),
        label: l10n.recruiterShellTabJobs,
      ),
      NavigationDestination(
        icon: const Icon(Icons.business_outlined),
        selectedIcon: const Icon(Icons.business),
        label: l10n.recruiterShellTabEmployer,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.shellTabProfile,
      ),
    ];
  }

  void _onTap(int i) {
    if (i == shell.currentIndex) {
      shell.goBranch(i, initialLocation: true);
    } else {
      shell.goBranch(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        destinations: _items(context),
        onDestinationSelected: _onTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: cs.surfaceContainerHighest,
        indicatorColor: cs.primaryContainer,
      ),
    );
  }
}
