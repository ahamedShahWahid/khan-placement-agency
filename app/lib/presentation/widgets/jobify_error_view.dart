import 'package:flutter/material.dart';

import 'package:jobify_app/core/error/exceptions.dart';
import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';

class JobifyErrorView extends StatelessWidget {
  const JobifyErrorView({
    super.key,
    this.error,
    this.headline,
    this.body,
    this.onRetry,
  });

  final Object? error;
  final String? headline;
  final String? body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (h, b) = _describe(context, error, headline, body);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: JobifySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: JobifySpacing.lg),
            Text(
              h,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JobifySpacing.sm),
            Text(
              b,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: JobifySpacing.lg),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.commonTryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, String) _describe(
    BuildContext context,
    Object? error,
    String? headline,
    String? body,
  ) {
    if (headline != null && body != null) return (headline, body);
    final l10n = context.l10n;
    switch (error) {
      case NetworkException _:
        return (
          headline ?? l10n.commonCouldntReachJobify,
          body ?? l10n.commonCheckConnectionRetry,
        );
      case AuthException _:
        return (
          headline ?? l10n.commonSignedOut,
          body ?? l10n.commonSessionEnded,
        );
      case ApiException(:final detail):
        return (
          headline ?? l10n.commonSomethingWentWrong,
          body ?? (detail ?? l10n.commonPleaseTryAgainMoment),
        );
      default:
        return (
          headline ?? l10n.commonSomethingWentWrong,
          body ?? l10n.commonUnexpectedError,
        );
    }
  }
}
