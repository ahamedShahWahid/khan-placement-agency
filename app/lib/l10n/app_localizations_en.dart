// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get shellTabFeed => 'Feed';

  @override
  String get shellTabSaved => 'Saved';

  @override
  String get shellTabApplications => 'Applications';

  @override
  String get shellTabProfile => 'Profile';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonOk => 'OK';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNothingHereYet => 'Nothing here yet';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonCouldntReachJobify => 'Couldn\'t reach Jobify';

  @override
  String get commonCheckConnectionRetry =>
      'Check your connection and try again.';

  @override
  String get commonSignedOut => 'Signed out';

  @override
  String get commonSessionEnded => 'Your session ended. Sign in to continue.';

  @override
  String get commonPleaseTryAgainMoment => 'Please try again in a moment.';

  @override
  String get commonUnexpectedError => 'An unexpected error occurred.';

  @override
  String get authAccountDeletedSnackbar => 'Your account has been deleted.';

  @override
  String get authSignInNetworkError =>
      'Couldn\'t reach Jobify. Check your connection.';

  @override
  String get authSignInFailed => 'Sign-in failed. Try again.';

  @override
  String get authHeroTitle => 'Job will\nfind you.';

  @override
  String get authHeroSubtitle =>
      'We read your résumé and bring the roles that fit — with the reason, and the catch, in plain words.';

  @override
  String get authWordmark => 'Jobify';

  @override
  String get authHeroRoleBackendEngineer => 'Backend Engineer';

  @override
  String get authHeroRoleProductDesigner => 'Product Designer';

  @override
  String get authHeroRoleDataEngineer => 'Data Engineer';

  @override
  String get authHeroSalaryRange => '₹18–28L';

  @override
  String get authHeroRemoteFirst => 'Remote-first';

  @override
  String get authHeroMatchPercent => '92% match';

  @override
  String get authSigningIn => 'Signing in…';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authGoogleSignInLoadError =>
      'Couldn\'t load Google sign-in. Refresh and try again.';

  @override
  String get onboardingCompanyNameTooShort =>
      'Enter your company name (min 2 characters)';

  @override
  String get onboardingCompanyNameTooLong => 'Company name is too long';

  @override
  String get onboardingGstinLength => 'GSTIN must be exactly 15 characters';

  @override
  String get onboardingCompanyNameTaken =>
      'That company name is already registered.';

  @override
  String get onboardingCreateEmployerFailed =>
      'Could not create employer. Please try again.';

  @override
  String get onboardingTitle => 'Set up your company';

  @override
  String get onboardingIntro =>
      'Tell us about your company to start posting jobs.';

  @override
  String get onboardingCompanyNameLabel => 'Company name';

  @override
  String get onboardingGstinLabel => 'GSTIN (optional)';

  @override
  String get onboardingCreateCompanyButton => 'Create company';

  @override
  String get feedRatingSaveError => 'Couldn\'t save your rating';

  @override
  String get feedHiddenSnackbar => 'Hidden from your feed';

  @override
  String get feedHeaderTitle => 'For you';

  @override
  String get feedHeaderSubtitle => 'Roles matched to your profile';

  @override
  String get feedEmptyHeadline => 'We\'re still looking for matches';

  @override
  String get feedEmptyBody =>
      'Upload a resume to help us find you better roles.';

  @override
  String get feedFilteredEmptyHeadline => 'Nothing matches your filters';

  @override
  String get feedFilteredEmptyBody =>
      'Try removing a filter or broadening your search.';

  @override
  String get feedClearFiltersButton => 'Clear filters';

  @override
  String get feedAllCaughtUp => 'You\'re all caught up';

  @override
  String feedNewMatchesSinceVisit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new matches since your last visit',
      one: '1 new match since your last visit',
    );
    return '$_temp0';
  }

  @override
  String get feedThumbUpTooltip => 'Good match';

  @override
  String get feedThumbDownTooltip => 'Not interested';

  @override
  String matchCaveatPrefix(String reason) {
    return 'Counts against: $reason';
  }

  @override
  String get feedClosedPill => 'Closed';

  @override
  String feedPostedMonthsAgo(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '${months}mo ago',
      one: '${months}mo ago',
    );
    return '$_temp0';
  }

  @override
  String feedPostedDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String feedPostedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '${hours}h ago',
      one: '${hours}h ago',
    );
    return '$_temp0';
  }

  @override
  String get feedPostedJustNow => 'just now';

  @override
  String get feedSearchHint => 'Search title or company';

  @override
  String get feedFiltersTooltip => 'Filters';

  @override
  String feedMinCtcChipLabel(String amount) {
    return '≥ ₹${amount}L';
  }

  @override
  String feedYearsSuffix(int years) {
    return '$years yrs';
  }

  @override
  String get feedClearAllButton => 'Clear all';

  @override
  String get feedFilterSheetTitle => 'Filter matches';

  @override
  String get feedFilterLocationLabel => 'Location';

  @override
  String get feedFilterAddCityHint => 'Add another city';

  @override
  String get feedFilterExperienceLabel => 'Experience';

  @override
  String get feedFilterExperienceAny => 'Any';

  @override
  String get feedFilterMinCtcLabel => 'Minimum CTC (lakhs)';

  @override
  String get feedFilterCtcHint => 'e.g. 5';

  @override
  String get feedFilterCtcPrefix => '₹ ';

  @override
  String get feedFilterCtcSuffix => 'L';

  @override
  String get feedFilterResetButton => 'Reset';

  @override
  String get feedFilterApplyButton => 'Apply';

  @override
  String get feedCityBangalore => 'Bangalore';

  @override
  String get feedCityMumbai => 'Mumbai';

  @override
  String get feedCityDelhiNcr => 'Delhi NCR';

  @override
  String get feedCityHyderabad => 'Hyderabad';

  @override
  String get feedCityChennai => 'Chennai';

  @override
  String get feedCityPune => 'Pune';

  @override
  String get feedCityRemote => 'Remote';

  @override
  String get feedSummaryUploadResume => 'Upload résumé';

  @override
  String get feedSummaryFinishProfile => 'Finish your profile';

  @override
  String get feedSummaryProfileComplete => 'Profile complete';

  @override
  String get jobDetailActionFailed => 'Action failed';

  @override
  String get jobDetailNetworkError => 'Couldn\'t reach Jobify.';

  @override
  String get jobDetailGoneHeadline => 'This job is no longer available';

  @override
  String get jobDetailGoneBody => 'It may have been closed or removed.';

  @override
  String get jobDetailWhyThisMatch => 'Why this match';

  @override
  String get jobDetailMatchFeedbackPrompt => 'Was this match right for you?';

  @override
  String get jobDetailTimelineHeading => 'Timeline';

  @override
  String get jobDetailApplyButton => 'Apply';

  @override
  String get jobDetailWithdrawButton => 'Withdraw';

  @override
  String get jobDetailWithdrawDialogTitle => 'Withdraw application?';

  @override
  String get jobDetailWithdrawDialogBody =>
      'You can re-apply later if you change your mind.';

  @override
  String get savedHeaderTitle => 'Saved';

  @override
  String get savedHeaderSubtitle => 'Jobs you kept for later';

  @override
  String get savedEmptyHeadline => 'Nothing saved yet';

  @override
  String get savedEmptyBody => 'Tap the heart on any job to save it for later.';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get stageApplied => 'Applied';

  @override
  String get stageShortlisted => 'Shortlisted';

  @override
  String get stageInterview => 'Interview';

  @override
  String get stageOffer => 'Offer';

  @override
  String get stageHired => 'Hired';

  @override
  String get stageRejected => 'Not selected';

  @override
  String get stageInProgress => 'In progress';

  @override
  String get stageWithdrawn => 'Withdrawn';

  @override
  String get applicationsHeaderTitle => 'Applications';

  @override
  String get applicationsHeaderSubtitle => 'Roles you applied to';

  @override
  String get applicationsEmptyHeadline => 'No applications yet';

  @override
  String get applicationsEmptyBody =>
      'Browse the feed and apply to roles you like.';

  @override
  String get applicationsBrowseFeedButton => 'Browse the feed';

  @override
  String applicationsWithdrawnOn(String when) {
    return 'Withdrawn $when';
  }

  @override
  String applicationsAppliedOn(String when) {
    return 'Applied $when';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String notificationApplicationReceivedWithEmployer(
      String job, String employer) {
    return 'Application received for $job at $employer';
  }

  @override
  String notificationApplicationReceivedWithJob(String job) {
    return 'Application received for $job';
  }

  @override
  String get notificationApplicationReceived => 'Application received';

  @override
  String notificationStageShortlistedJob(String job) {
    return 'Shortlisted for $job';
  }

  @override
  String get notificationStageShortlisted => 'Shortlisted';

  @override
  String notificationStageInterviewJob(String job) {
    return 'Interview stage for $job';
  }

  @override
  String get notificationStageInterview => 'Interview stage';

  @override
  String notificationStageOfferJob(String job) {
    return 'You have an offer for $job';
  }

  @override
  String get notificationStageOffer => 'You have an offer';

  @override
  String notificationStageHiredJob(String job) {
    return 'You were hired for $job';
  }

  @override
  String get notificationStageHired => 'You were hired';

  @override
  String notificationStageRejectedJob(String job) {
    return 'Update on your application for $job';
  }

  @override
  String get notificationStageRejected => 'Update on your application';

  @override
  String notificationStageDefaultJob(String job) {
    return 'Application updated for $job';
  }

  @override
  String get notificationStageDefault => 'Application updated';

  @override
  String get privacyTitle => 'Privacy & data';

  @override
  String get privacyMutationErrorSnackbar =>
      'Couldn\'t update preference. Change was reverted.';

  @override
  String get privacyNotificationPrefsHeading => 'Notification preferences';

  @override
  String get privacyConsentEmailTransactionalTitle => 'Service updates';

  @override
  String get privacyConsentEmailTransactionalSubtitle =>
      'Email about your applications, matches, and account.';

  @override
  String get privacyConsentEmailMarketingTitle => 'Job recommendations';

  @override
  String get privacyConsentEmailMarketingSubtitle =>
      'Weekly digest of jobs that fit your profile.';

  @override
  String get privacyConsentInAppTitle => 'In-app notifications';

  @override
  String get privacyConsentInAppSubtitle => 'See alerts inside the app.';

  @override
  String get privacyYourDataHeading => 'Your data';

  @override
  String get privacyYourDataBody =>
      'A copy of everything we know about you (JSON).';

  @override
  String get privacyDownloadDataButton => 'Download my data';

  @override
  String get profileAccountHeading => 'Account';

  @override
  String get privacyDeleteBody =>
      'Permanently erase your data. This can\'t be undone.';

  @override
  String get privacyDeleteAccountButton => 'Delete my account';

  @override
  String get privacyTurnOffEmailsDialogTitle => 'Turn off service emails?';

  @override
  String get privacyTurnOffEmailsDialogBody =>
      'You won\'t receive emails about your applications, matches, or account. Are you sure?';

  @override
  String get privacyTurnOffButton => 'Turn off';

  @override
  String get privacyExportSuccessSnackbar =>
      'Your data is on your clipboard.\nPaste it into a text editor and save as a .json file.';

  @override
  String get privacyExportErrorSnackbar =>
      'Couldn\'t export your data. Try again.';

  @override
  String get deleteAccountErrorSnackbar =>
      'Couldn\'t delete your account. Try again.';

  @override
  String get deleteAccountWarningBanner =>
      'This will permanently delete your personal data on Jobify. This action is irreversible.';

  @override
  String get deleteAccountWhatWillHappenHeading => 'What will happen:';

  @override
  String get deleteAccountBulletProfile =>
      'Your profile, resume, applications, and saved jobs are removed.';

  @override
  String get deleteAccountBulletMatchHistory =>
      'Your match history and notifications are erased.';

  @override
  String get deleteAccountBulletAnalytics =>
      'Anonymized employer-side analytics survive (apply counts only).';

  @override
  String get deleteAccountDownloadHint =>
      'Before you continue, we recommend downloading your data.';

  @override
  String deleteAccountConfirmPrompt(String phrase) {
    return 'To confirm, type $phrase below:';
  }

  @override
  String get deleteAccountConfirmDialogTitle => 'Are you absolutely sure?';

  @override
  String get deleteAccountConfirmDialogBody =>
      'Your account and all associated data will be permanently deleted.';

  @override
  String get deleteAccountYesDeleteButton => 'Yes, delete';

  @override
  String get resumeUnsupportedFileType =>
      'Unsupported file type (PDF, DOC, DOCX).';

  @override
  String get resumeFileTooLarge => 'File too large (max 10 MB).';

  @override
  String get resumeNetworkError => 'Couldn\'t reach Jobify.';

  @override
  String get resumeUploadFailedGeneric => 'Couldn\'t upload. Try again.';

  @override
  String get resumeTitle => 'Résumé';

  @override
  String get resumeUploadingButton => 'Uploading…';

  @override
  String get resumeUploadButton => 'Upload / Replace résumé';

  @override
  String get resumeEmptyBody =>
      'No résumé yet. Upload one so we can match you to roles.';

  @override
  String get resumeStatusReady => 'Ready';

  @override
  String get resumeStatusFailed => 'Couldn\'t parse — try again';

  @override
  String get resumeStatusProcessing => 'Processing…';

  @override
  String resumeUploadedOn(String when) {
    return 'Uploaded $when';
  }

  @override
  String get preferencesTitle => 'What are you looking for?';

  @override
  String get preferencesSkipButton => 'Skip';

  @override
  String get preferencesLoadError => 'Couldn\'t load your preferences.';

  @override
  String get preferencesSectionHeading => 'Your preferences';

  @override
  String get preferencesDesiredRoleLabel => 'Desired role';

  @override
  String get preferencesNoPreferenceOption => 'No preference';

  @override
  String get preferencesLocationsLabel => 'Locations';

  @override
  String get preferencesAddLocationLabel => 'Add location';

  @override
  String get preferencesExpectedCtcLabel => 'Expected CTC (₹/yr)';

  @override
  String get preferencesResumeUnparsedBody =>
      'We couldn\'t read your résumé — tell us directly below.';

  @override
  String get preferencesResumeHeading => 'Your résumé';

  @override
  String get formSaveFailedGeneric => 'Couldn\'t save. Try again.';

  @override
  String get desiredRoleSoftwareEngineering => 'Software Engineering';

  @override
  String get desiredRoleDataAnalytics => 'Data & Analytics';

  @override
  String get desiredRoleProductManagement => 'Product Management';

  @override
  String get desiredRoleDesign => 'Design';

  @override
  String get desiredRoleSales => 'Sales';

  @override
  String get desiredRoleMarketing => 'Marketing';

  @override
  String get desiredRoleCustomerSupport => 'Customer Support';

  @override
  String get desiredRoleOperations => 'Operations';

  @override
  String get desiredRoleFinanceAccounting => 'Finance & Accounting';

  @override
  String get desiredRoleHrRecruiting => 'HR & Recruiting';

  @override
  String get desiredRoleLegal => 'Legal';

  @override
  String get desiredRoleConsulting => 'Consulting';

  @override
  String get desiredRoleBusinessDevelopment => 'Business Development';

  @override
  String get desiredRoleContentCommunications => 'Content & Communications';

  @override
  String get desiredRoleAdministration => 'Administration';

  @override
  String get desiredRoleOther => 'Other';

  @override
  String get desiredRoleUnknown => 'Unknown';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEditButton => 'Edit';

  @override
  String get profileHiringCtaTitle => 'I\'m hiring — post a job';

  @override
  String get profileHiringCtaSubtitle =>
      'Create your company to start recruiting';

  @override
  String get profileMatchProfileHeading => 'Match profile';

  @override
  String get profileResumeSubtitle => 'Manage your résumé';

  @override
  String get profileNotificationsSubtitle => 'View your notifications';

  @override
  String get profileInvitesSubtitle => 'Company invites to recruit';

  @override
  String get profilePrivacySubtitle => 'Preferences, export, delete';

  @override
  String get profileAppearanceHeading => 'Appearance';

  @override
  String get profileAppearanceSystem => 'System';

  @override
  String get profileAppearanceLight => 'Light';

  @override
  String get profileAppearanceDark => 'Dark';

  @override
  String get profileLanguageLabel => 'Language';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileLanguageHindi => 'हिन्दी';

  @override
  String get profileSigningOutButton => 'Signing out…';

  @override
  String get profileSignOutButton => 'Sign out';

  @override
  String get profileSignOutDialogTitle => 'Sign out?';

  @override
  String get profileSignOutDialogBody =>
      'You\'ll need to sign in again to continue.';

  @override
  String get profileRetryPreferencesLabel => 'Preferences';

  @override
  String get profileExperienceLabel => 'Experience';

  @override
  String get profileNoticePeriodLabel => 'Notice period';

  @override
  String profileNoticePeriodDaysValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String get profileCurrentCtcLabel => 'Current CTC';

  @override
  String get profileExpectedCtcLabel => 'Expected CTC';

  @override
  String get profileRetryFailedLabel => 'Couldn\'t load';

  @override
  String get profileAddFieldAction => 'Add';

  @override
  String profileYearsExperienceSuffix(String years) {
    return '$years yrs';
  }

  @override
  String profileVersionLabel(String version, String build) {
    return 'v$version ($build)';
  }

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get editProfileLoadError => 'Couldn\'t load your profile.';

  @override
  String get editProfileAboutYouHeading => 'About you';

  @override
  String get editProfileFullNameLabel => 'Full name';

  @override
  String get editProfileRequiredValidation => 'Required';

  @override
  String get editProfileTooLongValidation => 'Too long (max 200)';

  @override
  String get editProfileLocationTooLong => 'Location too long (max 100 chars).';

  @override
  String get editProfileLocationsLimitReached => 'Up to 10 locations.';

  @override
  String get editProfileTheNumbersHeading => 'The numbers';

  @override
  String get editProfileYearsExperienceLabel => 'Years of experience';

  @override
  String get editProfileNoticePeriodLabel => 'Notice period (days)';

  @override
  String get editProfileCurrentCtcLabel => 'Current CTC (₹/yr)';

  @override
  String get editProfileEnterNumberValidation => 'Enter a number';

  @override
  String editProfileRangeValidation(num min, num max) {
    return 'Must be between $min and $max';
  }

  @override
  String get editProfileWholeNumberValidation => 'Whole number only';

  @override
  String editProfileDecimalPlacesValidation(int maxDecimals) {
    String _temp0 = intl.Intl.pluralLogic(
      maxDecimals,
      locale: localeName,
      other: 'At most $maxDecimals decimal places',
      one: 'At most $maxDecimals decimal place',
    );
    return '$_temp0';
  }

  @override
  String get editProfileSavedProfileOnly =>
      'Saved your profile, but couldn\'t save preferences. Try again.';

  @override
  String get editProfileSavedPreferencesOnly =>
      'Saved your preferences, but couldn\'t save your profile. Try again.';

  @override
  String get invitesTitle => 'Pending invitations';

  @override
  String get invitesEmptyHeadline => 'No invitations';

  @override
  String get invitesEmptyBody =>
      'When a company invites you to recruit, it\'ll show up here.';

  @override
  String invitesCardSubtitleOwner(String expires) {
    return 'Invited as owner · expires $expires';
  }

  @override
  String invitesCardSubtitleMember(String expires) {
    return 'Invited as member · expires $expires';
  }

  @override
  String get invitesDeclineButton => 'Decline';

  @override
  String get invitesAcceptButton => 'Accept';

  @override
  String invitesJoinedSnackbar(String employerName) {
    return 'You joined $employerName.';
  }

  @override
  String get invitesAcceptErrorSnackbar => 'Couldn\'t accept the invitation.';

  @override
  String get invitesDeclineErrorSnackbar => 'Couldn\'t decline the invitation.';
}
