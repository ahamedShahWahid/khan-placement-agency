import 'package:flutter/material.dart';

import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/data/feed/feed_dto.dart';
import 'package:jobify_app/data/feed/match_feedback_rating.dart';
import 'package:jobify_app/data/jobs/job_status.dart';
import 'package:jobify_app/presentation/theme/jobify_colors.dart';
import 'package:jobify_app/presentation/theme/jobify_radii.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';
import 'package:jobify_app/presentation/theme/jobify_typography.dart';
import 'package:jobify_app/presentation/widgets/jobify_score_badge.dart';

class FeedItemCard extends StatelessWidget {
  const FeedItemCard({
    required this.job,
    required this.employer,
    required this.onTap,
    this.match,
    this.explanation,
    this.showScore = true,
    this.myFeedback,
    this.onThumbUp,
    this.onThumbDown,
    super.key,
  });

  final JobSummaryDto job;
  final EmployerSummaryDto employer;
  final MatchSummaryDto? match;
  final ExplanationDto? explanation;
  final VoidCallback onTap;
  final bool showScore;
  final MatchFeedbackRating? myFeedback;
  final VoidCallback? onThumbUp;
  final VoidCallback? onThumbDown;

  String _ago(BuildContext context, DateTime d) {
    final l10n = context.l10n;
    final delta = DateTime.now().toUtc().difference(d.toUtc());
    if (delta.inDays >= 30) {
      return l10n.feedPostedMonthsAgo((delta.inDays / 30).floor());
    }
    if (delta.inDays >= 1) return l10n.feedPostedDaysAgo(delta.inDays);
    if (delta.inHours >= 1) return l10n.feedPostedHoursAgo(delta.inHours);
    return l10n.feedPostedJustNow;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClosed = job.status != JobStatus.open;
    final meta = [
      if (job.locations.isNotEmpty) job.locations.join(', '),
      _ago(context, job.postedAt),
    ].join(' · ');
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(JobifySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      employer.name.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: JobifySpacing.sm),
                  if (isClosed)
                    const _ClosedPill()
                  else if (showScore && match != null)
                    JobifyScoreBadge(score: match!.totalScore),
                ],
              ),
              const SizedBox(height: JobifySpacing.xs),
              Text(job.title, style: theme.textTheme.titleMedium),
              if (explanation != null) ...[
                const SizedBox(height: JobifySpacing.sm),
                Text(
                  explanation!.fit,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: -0.3,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (explanation!.caveat != null) ...[
                  const SizedBox(height: JobifySpacing.sm),
                  _CaveatLine(text: explanation!.caveat!),
                ],
              ],
              const SizedBox(height: JobifySpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      style: JobifyTypography.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!isClosed &&
                      onThumbUp != null &&
                      onThumbDown != null) ...[
                    IconButton(
                      tooltip: context.l10n.feedThumbUpTooltip,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        myFeedback == MatchFeedbackRating.up
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 18,
                      ),
                      onPressed: onThumbUp,
                    ),
                    IconButton(
                      tooltip: context.l10n.feedThumbDownTooltip,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.thumb_down_outlined, size: 18),
                      onPressed: onThumbDown,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaveatLine extends StatelessWidget {
  const _CaveatLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amber = isDark ? JobifyColors.caveatDark : JobifyColors.caveatLight;
    return Container(
      padding: const EdgeInsets.only(left: JobifySpacing.sm),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: amber, width: 2.5)),
      ),
      child: Text(
        context.l10n.matchCaveatPrefix(text),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: amber),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ClosedPill extends StatelessWidget {
  const _ClosedPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JobifySpacing.sm,
        vertical: JobifySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: JobifyRadii.borderRadiusPill,
      ),
      child: Text(
        context.l10n.feedClosedPill,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
