import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/data/jobs/application_status.dart';
import 'package:jobify_app/data/jobs/jobs_dto.dart';
import 'package:jobify_app/presentation/job_detail/apply_to_job_controller.dart';
import 'package:jobify_app/presentation/job_detail/save_job_controller.dart';
import 'package:jobify_app/presentation/job_detail/unsave_job_controller.dart';
import 'package:jobify_app/presentation/job_detail/withdraw_application_controller.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';

class ActionBar extends ConsumerWidget {
  const ActionBar({required this.detail, super.key});
  final JobDetailDto detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = detail.application;
    final saved = detail.savedJob;
    final jobId = detail.job.id;

    final applyState = ref.watch(applyToJobControllerProvider(jobId));
    final withdrawState =
        app == null
            ? const AsyncValue<ApplicationDto?>.data(null)
            : ref.watch(withdrawApplicationControllerProvider(app.id));
    final saveState = ref.watch(saveJobControllerProvider(jobId));
    final unsaveState = ref.watch(unsaveJobControllerProvider(jobId));

    final isBusy =
        applyState.isLoading ||
        withdrawState.isLoading ||
        saveState.isLoading ||
        unsaveState.isLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(JobifySpacing.lg),
        child: Row(
          children: [
            Expanded(child: _applyOrWithdraw(context, ref, app, jobId, isBusy)),
            const SizedBox(width: JobifySpacing.md),
            _saveHeart(context, ref, saved, jobId, isBusy),
          ],
        ),
      ),
    );
  }

  Widget _applyOrWithdraw(
    BuildContext ctx,
    WidgetRef ref,
    ApplicationDto? app,
    String jobId,
    bool isBusy,
  ) {
    if (app == null || app.status == ApplicationStatus.withdrawn) {
      return FilledButton(
        onPressed:
            isBusy
                ? null
                : () =>
                    ref
                        .read(applyToJobControllerProvider(jobId).notifier)
                        .submit(),
        child: Text(ctx.l10n.jobDetailApplyButton),
      );
    }
    return OutlinedButton(
      onPressed: isBusy ? null : () => _confirmWithdraw(ctx, ref, app, jobId),
      child: Text(ctx.l10n.jobDetailWithdrawButton),
    );
  }

  Widget _saveHeart(
    BuildContext ctx,
    WidgetRef ref,
    SavedJobDto? saved,
    String jobId,
    bool isBusy,
  ) {
    final filled = saved != null;
    return IconButton.filledTonal(
      onPressed:
          isBusy
              ? null
              : () {
                if (filled) {
                  ref
                      .read(unsaveJobControllerProvider(jobId).notifier)
                      .submit();
                } else {
                  ref.read(saveJobControllerProvider(jobId).notifier).submit();
                }
              },
      icon: Icon(filled ? Icons.bookmark : Icons.bookmark_outline),
    );
  }

  Future<void> _confirmWithdraw(
    BuildContext ctx,
    WidgetRef ref,
    ApplicationDto app,
    String jobId,
  ) async {
    final l10n = ctx.l10n;
    final ok = await showDialog<bool>(
      context: ctx,
      builder:
          (c) => AlertDialog(
            title: Text(l10n.jobDetailWithdrawDialogTitle),
            content: Text(l10n.jobDetailWithdrawDialogBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.jobDetailWithdrawButton),
              ),
            ],
          ),
    );
    if (ok ?? false) {
      await ref
          .read(withdrawApplicationControllerProvider(app.id).notifier)
          .submit(jobId: jobId);
    }
  }
}
