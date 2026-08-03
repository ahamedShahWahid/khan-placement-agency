// ignore_for_file: directives_ordering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jobify_app/core/consent/consent_scope.dart';
import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/l10n/app_localizations.dart';
import 'package:jobify_app/presentation/privacy/privacy_controller.dart';
import 'package:jobify_app/presentation/privacy/privacy_state.dart';
import 'package:jobify_app/presentation/routing/routes.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';
import 'package:jobify_app/presentation/widgets/async_value_widget.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(privacyControllerProvider);
    final l10n = context.l10n;

    // Show rollback snackbar whenever mutationError is set.
    ref.listen<AsyncValue<PrivacyState>>(privacyControllerProvider, (_, next) {
      final err = next.value?.mutationError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.privacyMutationErrorSnackbar)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: AsyncValueWidget(
        value: state,
        onRetry: () => ref.invalidate(privacyControllerProvider),
        data: (data) => _PrivacyBody(data: data),
      ),
    );
  }
}

class _PrivacyBody extends ConsumerWidget {
  const _PrivacyBody({required this.data});

  final PrivacyState data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // Build a lookup map from scope wire string → granted bool.
    final consentMap = {
      for (final c in data.consents) c.scope: c.granted,
    };

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(JobifySpacing.lg),
          children: [
            // ── Notification preferences section ──────────────────────────
            Text(
              l10n.privacyNotificationPrefsHeading,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: JobifySpacing.sm),
            ...ConsentScope.v0VisibleScopes.map((scope) {
              final granted = consentMap[scope.wire] ?? false;
              final labels = _consentLabel(l10n, scope);
              return SwitchListTile.adaptive(
                key: Key('toggle-${scope.wire}'),
                title: Text(labels.$1),
                subtitle: Text(labels.$2),
                value: granted,
                onChanged: (val) => _onToggle(context, ref, scope, val),
                contentPadding: EdgeInsets.zero,
              );
            }),

            const SizedBox(height: JobifySpacing.xl),
            const Divider(),
            const SizedBox(height: JobifySpacing.xl),

            // ── Your data section ─────────────────────────────────────────
            Text(
              l10n.privacyYourDataHeading,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: JobifySpacing.sm),
            Text(
              l10n.privacyYourDataBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: JobifySpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.privacyDownloadDataButton),
              onPressed: data.exportInProgress
                  ? null
                  : () => _exportData(context, ref),
            ),

            const SizedBox(height: JobifySpacing.xl),
            const Divider(),
            const SizedBox(height: JobifySpacing.xl),

            // ── Account section ───────────────────────────────────────────
            Text(
              l10n.profileAccountHeading,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: JobifySpacing.sm),
            Text(
              l10n.privacyDeleteBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: JobifySpacing.md),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => context.go(Routes.privacyDelete),
              child: Text(l10n.privacyDeleteAccountButton),
            ),
          ],
        ),

        // Export-in-progress overlay.
        if (data.exportInProgress)
          const ModalBarrier(dismissible: false, color: Colors.black26),
        if (data.exportInProgress)
          const Center(child: CircularProgressIndicator.adaptive()),
      ],
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    ConsentScope scope,
    bool val,
  ) async {
    // email_transactional OFF requires confirmation first.
    if (scope == ConsentScope.emailTransactional && !val) {
      final l10n = context.l10n;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.privacyTurnOffEmailsDialogTitle),
          content: Text(l10n.privacyTurnOffEmailsDialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.privacyTurnOffButton),
            ),
          ],
        ),
      );
      if (!(ok ?? false)) return;
    }

    await ref
        .read(privacyControllerProvider.notifier)
        .setConsent(scope.wire, granted: val);
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final result =
        await ref.read(privacyControllerProvider.notifier).exportData();
    if (!context.mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.privacyExportSuccessSnackbar)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.privacyExportErrorSnackbar)),
      );
    }
  }
}

/// Returns (title, subtitle) for a consent scope.
({String title, String subtitle}) _consentLabelRecord(
  AppLocalizations l10n,
  ConsentScope scope,
) {
  return switch (scope) {
    ConsentScope.emailTransactional => (
        title: l10n.privacyConsentEmailTransactionalTitle,
        subtitle: l10n.privacyConsentEmailTransactionalSubtitle,
      ),
    ConsentScope.emailMarketing => (
        title: l10n.privacyConsentEmailMarketingTitle,
        subtitle: l10n.privacyConsentEmailMarketingSubtitle,
      ),
    ConsentScope.inAppNotifications => (
        title: l10n.privacyConsentInAppTitle,
        subtitle: l10n.privacyConsentInAppSubtitle,
      ),
    _ => (title: scope.wire, subtitle: ''),
  };
}

(String, String) _consentLabel(AppLocalizations l10n, ConsentScope scope) {
  final r = _consentLabelRecord(l10n, scope);
  return (r.title, r.subtitle);
}
