import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jobify_app/core/format/date_formats.dart';
import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/data/employers/team/employer_invite_dto.dart';
import 'package:jobify_app/presentation/invites/invite_response_controller.dart';
import 'package:jobify_app/presentation/invites/my_invites_controller.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';
import 'package:jobify_app/presentation/widgets/async_value_widget.dart';
import 'package:jobify_app/presentation/widgets/jobify_empty_state.dart';

/// Applicant-reachable list of pending employer invitations.
///
/// Accepting refreshes the session → role flips to recruiter → the role-aware
/// redirect moves the user into the recruiter shell automatically.
class PendingInvitesScreen extends ConsumerWidget {
  const PendingInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myInvitesControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.invitesTitle)),
      body: AsyncValueWidget<List<MyInviteDto>>(
        value: invites,
        onRetry: () => ref.read(myInvitesControllerProvider.notifier).refresh(),
        isEmpty: (list) => list.isEmpty,
        empty:
            () => JobifyEmptyState(
              headline: l10n.invitesEmptyHeadline,
              body: l10n.invitesEmptyBody,
              icon: Icons.mail_outline,
            ),
        data:
            (list) => RefreshIndicator(
              onRefresh:
                  () =>
                      ref.read(myInvitesControllerProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.all(JobifySpacing.lg),
                itemCount: list.length,
                separatorBuilder:
                    (_, __) => const SizedBox(height: JobifySpacing.md),
                itemBuilder: (_, i) => _InviteCard(invite: list[i]),
              ),
            ),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});
  final MyInviteDto invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final busy = ref.watch(inviteResponseControllerProvider).isLoading;
    final expires = jobifyLongDateFormat.format(invite.expiresAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(JobifySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invite.employerName, style: theme.textTheme.titleMedium),
            const SizedBox(height: JobifySpacing.xs),
            Text(
              invite.role == 'owner'
                  ? l10n.invitesCardSubtitleOwner(expires)
                  : l10n.invitesCardSubtitleMember(expires),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: JobifySpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => _decline(context, ref),
                  child: Text(l10n.invitesDeclineButton),
                ),
                const SizedBox(width: JobifySpacing.sm),
                FilledButton(
                  onPressed: busy ? null : () => _accept(context, ref),
                  child: Text(l10n.invitesAcceptButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await ref
        .read(inviteResponseControllerProvider.notifier)
        .accept(invite.id);
    if (ok) {
      // Role flips to recruiter → router redirects to the recruiter shell.
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.invitesJoinedSnackbar(invite.employerName)),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.invitesAcceptErrorSnackbar)),
      );
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await ref
        .read(inviteResponseControllerProvider.notifier)
        .decline(invite.id);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.invitesDeclineErrorSnackbar)),
      );
    }
  }
}
