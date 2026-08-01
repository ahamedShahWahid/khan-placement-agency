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
  String get recruiterShellTabDashboard => 'Dashboard';

  @override
  String get recruiterShellTabJobs => 'Jobs';

  @override
  String get recruiterShellTabEmployer => 'Employer';

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
    return '${months}mo ago';
  }

  @override
  String feedPostedDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String feedPostedHoursAgo(int hours) {
    return '${hours}h ago';
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
}
