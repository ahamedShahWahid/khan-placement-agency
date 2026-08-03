import 'package:jobify_app/data/notifications/notification_dto.dart';
import 'package:jobify_app/l10n/app_localizations.dart';

/// Human-readable title for a notification, from its kind + payload. Every
/// payload read is null-guarded (payload is an untyped wire dict).
String notificationTitle(AppLocalizations l10n, NotificationDto n) {
  final p = n.payload;
  switch (n.kind) {
    case 'application_received':
      final job = p['job_title'] as String?;
      final emp = p['employer_name'] as String?;
      if (job != null && emp != null) {
        return l10n.notificationApplicationReceivedWithEmployer(job, emp);
      }
      if (job != null) return l10n.notificationApplicationReceivedWithJob(job);
      return l10n.notificationApplicationReceived;
    case 'application_stage_changed':
      final job = p['job_title'] as String?;
      final stage = p['stage'] as String?;
      if (job != null) {
        return switch (stage) {
          'shortlisted' => l10n.notificationStageShortlistedJob(job),
          'interview' => l10n.notificationStageInterviewJob(job),
          'offer' => l10n.notificationStageOfferJob(job),
          'hired' => l10n.notificationStageHiredJob(job),
          'rejected' => l10n.notificationStageRejectedJob(job),
          _ => l10n.notificationStageDefaultJob(job),
        };
      }
      return switch (stage) {
        'shortlisted' => l10n.notificationStageShortlisted,
        'interview' => l10n.notificationStageInterview,
        'offer' => l10n.notificationStageOffer,
        'hired' => l10n.notificationStageHired,
        'rejected' => l10n.notificationStageRejected,
        _ => l10n.notificationStageDefault,
      };
    default:
      // Kind is a wire value, not user-facing content — a graceful fallback
      // for a notification kind this build doesn't recognise yet. English,
      // by design: there's no translation for an arbitrary future wire slug.
      return _humanize(n.kind);
  }
}

String _humanize(String kind) {
  if (kind.isEmpty) return 'Notification';
  final words = kind.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}
