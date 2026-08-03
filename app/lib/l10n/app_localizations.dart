import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// Bottom navigation tab label for the job feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get shellTabFeed;

  /// Bottom navigation tab label for saved jobs.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get shellTabSaved;

  /// Bottom navigation tab label for the applicant's applications.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get shellTabApplications;

  /// Bottom navigation tab label for the applicant's profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get shellTabProfile;

  /// Button label to retry a failed action or request.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Button label to cancel an in-progress action or dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button label to save a form or setting.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic loading indicator caption.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// Button label to acknowledge/dismiss a dialog.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Generic error headline shown when an action or load fails.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// Button label to undo the last action (shown in a SnackBar).
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// Tooltip for a refresh icon button.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Button label to go back to the previous screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Default empty-state headline used when no more specific copy is supplied.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonNothingHereYet;

  /// Button label on the generic error view to retry the failed action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Generic error headline shown when a network request fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Jobify'**
  String get commonCouldntReachJobify;

  /// Generic error body shown alongside commonCouldntReachJobify.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get commonCheckConnectionRetry;

  /// Generic error headline shown when the user's session has ended.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get commonSignedOut;

  /// Generic error body shown alongside commonSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in to continue.'**
  String get commonSessionEnded;

  /// Fallback error body when the server didn't provide a detail message.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get commonPleaseTryAgainMoment;

  /// Fallback error body for an unrecognised error type.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get commonUnexpectedError;

  /// Snackbar shown on the sign-in screen right after a successful account deletion.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get authAccountDeletedSnackbar;

  /// Snackbar shown when sign-in fails due to a network error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Jobify. Check your connection.'**
  String get authSignInNetworkError;

  /// Snackbar shown when sign-in fails for an unspecified or generic reason.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Try again.'**
  String get authSignInFailed;

  /// Sign-in screen hero headline — the brand promise.
  ///
  /// In en, this message translates to:
  /// **'Job will\nfind you.'**
  String get authHeroTitle;

  /// Sign-in screen hero sub-headline explaining the product.
  ///
  /// In en, this message translates to:
  /// **'We read your résumé and bring the roles that fit — with the reason, and the catch, in plain words.'**
  String get authHeroSubtitle;

  /// The Jobify product wordmark on the sign-in screen. Product name — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Jobify'**
  String get authWordmark;

  /// Illustrative job-title chip in the sign-in hero animation. Job title — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Backend Engineer'**
  String get authHeroRoleBackendEngineer;

  /// Illustrative job-title chip in the sign-in hero animation. Job title — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Product Designer'**
  String get authHeroRoleProductDesigner;

  /// Illustrative job-title chip in the sign-in hero animation. Job title — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Data Engineer'**
  String get authHeroRoleDataEngineer;

  /// Illustrative salary-range chip in the sign-in hero animation.
  ///
  /// In en, this message translates to:
  /// **'₹18–28L'**
  String get authHeroSalaryRange;

  /// Illustrative work-arrangement chip in the sign-in hero animation.
  ///
  /// In en, this message translates to:
  /// **'Remote-first'**
  String get authHeroRemoteFirst;

  /// Illustrative match-score chip in the sign-in hero animation.
  ///
  /// In en, this message translates to:
  /// **'92% match'**
  String get authHeroMatchPercent;

  /// Sign-in button label while the sign-in request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get authSigningIn;

  /// Sign-in button label (mobile).
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// Web sign-in fallback message shown if the Google Identity Services client fails to initialize.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load Google sign-in. Refresh and try again.'**
  String get authGoogleSignInLoadError;

  /// Validation error when the employer onboarding company-name field is too short.
  ///
  /// In en, this message translates to:
  /// **'Enter your company name (min 2 characters)'**
  String get onboardingCompanyNameTooShort;

  /// Validation error when the employer onboarding company-name field is too long.
  ///
  /// In en, this message translates to:
  /// **'Company name is too long'**
  String get onboardingCompanyNameTooLong;

  /// Validation error when the employer onboarding GSTIN field is the wrong length.
  ///
  /// In en, this message translates to:
  /// **'GSTIN must be exactly 15 characters'**
  String get onboardingGstinLength;

  /// Snackbar shown when creating an employer fails because the name is already taken.
  ///
  /// In en, this message translates to:
  /// **'That company name is already registered.'**
  String get onboardingCompanyNameTaken;

  /// Snackbar shown when creating an employer fails for a generic reason.
  ///
  /// In en, this message translates to:
  /// **'Could not create employer. Please try again.'**
  String get onboardingCreateEmployerFailed;

  /// AppBar title for the employer onboarding screen.
  ///
  /// In en, this message translates to:
  /// **'Set up your company'**
  String get onboardingTitle;

  /// Employer onboarding screen intro copy.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your company to start posting jobs.'**
  String get onboardingIntro;

  /// Label for the company name text field.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get onboardingCompanyNameLabel;

  /// Label for the optional GSTIN text field.
  ///
  /// In en, this message translates to:
  /// **'GSTIN (optional)'**
  String get onboardingGstinLabel;

  /// Submit button label for the employer onboarding form.
  ///
  /// In en, this message translates to:
  /// **'Create company'**
  String get onboardingCreateCompanyButton;

  /// Snackbar shown when a thumbs up/down match-feedback rating fails to save.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your rating'**
  String get feedRatingSaveError;

  /// Snackbar shown after thumbs-down hides a job from the feed.
  ///
  /// In en, this message translates to:
  /// **'Hidden from your feed'**
  String get feedHiddenSnackbar;

  /// Feed screen header title.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get feedHeaderTitle;

  /// Feed screen header subtitle.
  ///
  /// In en, this message translates to:
  /// **'Roles matched to your profile'**
  String get feedHeaderSubtitle;

  /// Empty-state headline shown when the feed has no items and no filters are active.
  ///
  /// In en, this message translates to:
  /// **'We\'re still looking for matches'**
  String get feedEmptyHeadline;

  /// Empty-state body shown when the feed has no items and no filters are active.
  ///
  /// In en, this message translates to:
  /// **'Upload a resume to help us find you better roles.'**
  String get feedEmptyBody;

  /// Empty-state headline shown when the feed has no items because filters are active.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your filters'**
  String get feedFilteredEmptyHeadline;

  /// Empty-state body shown when the feed has no items because filters are active.
  ///
  /// In en, this message translates to:
  /// **'Try removing a filter or broadening your search.'**
  String get feedFilteredEmptyBody;

  /// Button in the filtered-empty state that clears all active feed filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get feedClearFiltersButton;

  /// Caption shown at the end of the feed list when there are no more items to load.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get feedAllCaughtUp;

  /// Headline showing how many new matches surfaced since the applicant's last feed visit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new match since your last visit} other{{count} new matches since your last visit}}'**
  String feedNewMatchesSinceVisit(int count);

  /// Tooltip for the thumbs-up (positive match feedback) icon button.
  ///
  /// In en, this message translates to:
  /// **'Good match'**
  String get feedThumbUpTooltip;

  /// Tooltip for the thumbs-down (negative match feedback) icon button.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get feedThumbDownTooltip;

  /// Prefix shown before a match's caveat/downside text.
  ///
  /// In en, this message translates to:
  /// **'Counts against: {reason}'**
  String matchCaveatPrefix(String reason);

  /// Pill label shown on a job card when the job listing is closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get feedClosedPill;

  /// Relative time since a job was posted, in months.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, one{{months}mo ago} other{{months}mo ago}}'**
  String feedPostedMonthsAgo(int months);

  /// Relative time since a job was posted, in days.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String feedPostedDaysAgo(int days);

  /// Relative time since a job was posted, in hours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, one{{hours}h ago} other{{hours}h ago}}'**
  String feedPostedHoursAgo(int hours);

  /// Relative time since a job was posted, when under an hour ago.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get feedPostedJustNow;

  /// Hint text for the feed search field.
  ///
  /// In en, this message translates to:
  /// **'Search title or company'**
  String get feedSearchHint;

  /// Tooltip for the feed filter icon button that opens the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get feedFiltersTooltip;

  /// Active-filter chip label for a minimum-CTC filter, in lakhs.
  ///
  /// In en, this message translates to:
  /// **'≥ ₹{amount}L'**
  String feedMinCtcChipLabel(String amount);

  /// Compact years-of-experience label, e.g. on a filter chip or the filter sheet stepper.
  ///
  /// In en, this message translates to:
  /// **'{years} yrs'**
  String feedYearsSuffix(int years);

  /// Button that clears every active feed filter at once.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get feedClearAllButton;

  /// Title of the feed filter bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Filter matches'**
  String get feedFilterSheetTitle;

  /// Section label for the location filter in the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get feedFilterLocationLabel;

  /// Hint text for the custom-city text field in the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Add another city'**
  String get feedFilterAddCityHint;

  /// Section label for the minimum-experience filter in the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get feedFilterExperienceLabel;

  /// Value shown for the experience stepper when no minimum is set.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get feedFilterExperienceAny;

  /// Section label for the minimum-CTC filter in the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Minimum CTC (lakhs)'**
  String get feedFilterMinCtcLabel;

  /// Hint text for the minimum-CTC text field in the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5'**
  String get feedFilterCtcHint;

  /// Currency prefix for the minimum-CTC text field in the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'₹ '**
  String get feedFilterCtcPrefix;

  /// Lakh-unit suffix for the minimum-CTC text field in the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get feedFilterCtcSuffix;

  /// Button that resets the filter sheet's draft state (keeps the search query).
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get feedFilterResetButton;

  /// Button that commits the filter sheet's draft state to the active feed filters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get feedFilterApplyButton;

  /// Preset city option in the feed location filter. City name — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Bangalore'**
  String get feedCityBangalore;

  /// Preset city option in the feed location filter. City name — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Mumbai'**
  String get feedCityMumbai;

  /// Preset city option in the feed location filter. City name — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Delhi NCR'**
  String get feedCityDelhiNcr;

  /// Preset city option in the feed location filter. City name — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Hyderabad'**
  String get feedCityHyderabad;

  /// Preset city option in the feed location filter. City name — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Chennai'**
  String get feedCityChennai;

  /// Preset city option in the feed location filter. City name — stays Latin in every locale.
  ///
  /// In en, this message translates to:
  /// **'Pune'**
  String get feedCityPune;

  /// Preset work-arrangement option in the feed location filter.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get feedCityRemote;

  /// Feed home-summary match-profile tile label prompting a résumé upload.
  ///
  /// In en, this message translates to:
  /// **'Upload résumé'**
  String get feedSummaryUploadResume;

  /// Feed home-summary match-profile tile label prompting completion of preferences.
  ///
  /// In en, this message translates to:
  /// **'Finish your profile'**
  String get feedSummaryFinishProfile;

  /// Feed home-summary match-profile tile label shown once the profile is complete.
  ///
  /// In en, this message translates to:
  /// **'Profile complete'**
  String get feedSummaryProfileComplete;

  /// Fallback snackbar message for a job-detail action error with no server detail.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get jobDetailActionFailed;

  /// Snackbar message for a job-detail action error caused by a network failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Jobify.'**
  String get jobDetailNetworkError;

  /// Empty-state headline shown when a job detail 404s (closed or removed).
  ///
  /// In en, this message translates to:
  /// **'This job is no longer available'**
  String get jobDetailGoneHeadline;

  /// Empty-state body shown when a job detail 404s (closed or removed).
  ///
  /// In en, this message translates to:
  /// **'It may have been closed or removed.'**
  String get jobDetailGoneBody;

  /// Heading for the match explanation card on the job detail screen.
  ///
  /// In en, this message translates to:
  /// **'Why this match'**
  String get jobDetailWhyThisMatch;

  /// Prompt above the thumbs up/down match-feedback row on the job detail screen.
  ///
  /// In en, this message translates to:
  /// **'Was this match right for you?'**
  String get jobDetailMatchFeedbackPrompt;

  /// Heading for the application stage-change timeline on the job detail screen.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get jobDetailTimelineHeading;

  /// Button label to apply to a job.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get jobDetailApplyButton;

  /// Button label to withdraw an application.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get jobDetailWithdrawButton;

  /// Confirmation dialog title for withdrawing an application.
  ///
  /// In en, this message translates to:
  /// **'Withdraw application?'**
  String get jobDetailWithdrawDialogTitle;

  /// Confirmation dialog body for withdrawing an application.
  ///
  /// In en, this message translates to:
  /// **'You can re-apply later if you change your mind.'**
  String get jobDetailWithdrawDialogBody;

  /// Saved screen header title. Not reused from shellTabSaved: the tab label is deliberately transliterated ("सेव्ड") to fit the NavigationBar's tight width, a constraint that doesn't apply to the full-width screen header.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedHeaderTitle;

  /// Saved screen header subtitle.
  ///
  /// In en, this message translates to:
  /// **'Jobs you kept for later'**
  String get savedHeaderSubtitle;

  /// Empty-state headline shown when the applicant has no saved jobs.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get savedEmptyHeadline;

  /// Empty-state body shown when the applicant has no saved jobs.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any job to save it for later.'**
  String get savedEmptyBody;

  /// Button label while a form submit is in flight. Reused by the preferences and edit-profile screens.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// Applicant-facing label for the 'applied' application stage.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get stageApplied;

  /// Applicant-facing label for the 'shortlisted' application stage.
  ///
  /// In en, this message translates to:
  /// **'Shortlisted'**
  String get stageShortlisted;

  /// Applicant-facing label for the 'interview' application stage.
  ///
  /// In en, this message translates to:
  /// **'Interview'**
  String get stageInterview;

  /// Applicant-facing label for the 'offer' application stage.
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get stageOffer;

  /// Applicant-facing label for the 'hired' application stage.
  ///
  /// In en, this message translates to:
  /// **'Hired'**
  String get stageHired;

  /// Applicant-facing label for the 'rejected' application stage — spec-locked softened wording.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get stageRejected;

  /// Applicant-facing label for an unrecognised/unknown application stage.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get stageInProgress;

  /// Stage-pill label shown when the application itself has been withdrawn (a status, not a pipeline stage).
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get stageWithdrawn;

  /// Applications screen header title.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get applicationsHeaderTitle;

  /// Applications screen header subtitle.
  ///
  /// In en, this message translates to:
  /// **'Roles you applied to'**
  String get applicationsHeaderSubtitle;

  /// Empty-state headline shown when the applicant has no applications.
  ///
  /// In en, this message translates to:
  /// **'No applications yet'**
  String get applicationsEmptyHeadline;

  /// Empty-state body shown when the applicant has no applications.
  ///
  /// In en, this message translates to:
  /// **'Browse the feed and apply to roles you like.'**
  String get applicationsEmptyBody;

  /// Button in the applications empty state that navigates to the feed.
  ///
  /// In en, this message translates to:
  /// **'Browse the feed'**
  String get applicationsBrowseFeedButton;

  /// Applications row caption when the application was withdrawn — {when} is a pre-formatted date.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn {when}'**
  String applicationsWithdrawnOn(String when);

  /// Applications row caption when the application is active — {when} is a pre-formatted date.
  ///
  /// In en, this message translates to:
  /// **'Applied {when}'**
  String applicationsAppliedOn(String when);

  /// Notifications screen AppBar title. Reused as the profile screen's notifications row title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Empty-state text shown when the applicant has no notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// Notification title for an 'application_received' notification with both a job title and employer name in its payload.
  ///
  /// In en, this message translates to:
  /// **'Application received for {job} at {employer}'**
  String notificationApplicationReceivedWithEmployer(
      String job, String employer);

  /// Notification title for an 'application_received' notification with only a job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Application received for {job}'**
  String notificationApplicationReceivedWithJob(String job);

  /// Notification title for an 'application_received' notification with no job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Application received'**
  String get notificationApplicationReceived;

  /// Notification title for an 'application_stage_changed' notification (stage: shortlisted) with a job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Shortlisted for {job}'**
  String notificationStageShortlistedJob(String job);

  /// Notification title for an 'application_stage_changed' notification (stage: shortlisted) with no job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Shortlisted'**
  String get notificationStageShortlisted;

  /// Notification title for an 'application_stage_changed' notification (stage: interview) with a job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Interview stage for {job}'**
  String notificationStageInterviewJob(String job);

  /// Notification title for an 'application_stage_changed' notification (stage: interview) with no job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Interview stage'**
  String get notificationStageInterview;

  /// Notification title for an 'application_stage_changed' notification (stage: offer) with a job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'You have an offer for {job}'**
  String notificationStageOfferJob(String job);

  /// Notification title for an 'application_stage_changed' notification (stage: offer) with no job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'You have an offer'**
  String get notificationStageOffer;

  /// Notification title for an 'application_stage_changed' notification (stage: hired) with a job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'You were hired for {job}'**
  String notificationStageHiredJob(String job);

  /// Notification title for an 'application_stage_changed' notification (stage: hired) with no job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'You were hired'**
  String get notificationStageHired;

  /// Notification title for an 'application_stage_changed' notification (stage: rejected) with a job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Update on your application for {job}'**
  String notificationStageRejectedJob(String job);

  /// Notification title for an 'application_stage_changed' notification (stage: rejected) with no job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Update on your application'**
  String get notificationStageRejected;

  /// Notification title for an 'application_stage_changed' notification with an unrecognised stage, with a job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Application updated for {job}'**
  String notificationStageDefaultJob(String job);

  /// Notification title for an 'application_stage_changed' notification with an unrecognised stage, with no job title in its payload.
  ///
  /// In en, this message translates to:
  /// **'Application updated'**
  String get notificationStageDefault;

  /// Privacy screen AppBar title. Reused as the profile screen's privacy row title.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyTitle;

  /// Snackbar shown when a consent-toggle update fails and is rolled back.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update preference. Change was reverted.'**
  String get privacyMutationErrorSnackbar;

  /// Section heading for the consent-toggle list on the privacy screen.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get privacyNotificationPrefsHeading;

  /// Title for the email_transactional consent toggle.
  ///
  /// In en, this message translates to:
  /// **'Service updates'**
  String get privacyConsentEmailTransactionalTitle;

  /// Subtitle for the email_transactional consent toggle.
  ///
  /// In en, this message translates to:
  /// **'Email about your applications, matches, and account.'**
  String get privacyConsentEmailTransactionalSubtitle;

  /// Title for the email_marketing consent toggle.
  ///
  /// In en, this message translates to:
  /// **'Job recommendations'**
  String get privacyConsentEmailMarketingTitle;

  /// Subtitle for the email_marketing consent toggle.
  ///
  /// In en, this message translates to:
  /// **'Weekly digest of jobs that fit your profile.'**
  String get privacyConsentEmailMarketingSubtitle;

  /// Title for the in_app_notifications consent toggle.
  ///
  /// In en, this message translates to:
  /// **'In-app notifications'**
  String get privacyConsentInAppTitle;

  /// Subtitle for the in_app_notifications consent toggle.
  ///
  /// In en, this message translates to:
  /// **'See alerts inside the app.'**
  String get privacyConsentInAppSubtitle;

  /// Section heading for the DSR-export section of the privacy screen.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get privacyYourDataHeading;

  /// Body text for the DSR-export section of the privacy screen.
  ///
  /// In en, this message translates to:
  /// **'A copy of everything we know about you (JSON).'**
  String get privacyYourDataBody;

  /// Button that triggers a DSR data export. Reused on the delete-account screen.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get privacyDownloadDataButton;

  /// Section heading for account-level actions. Used on both the profile screen and the privacy screen.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountHeading;

  /// Body text for the delete-account section of the privacy screen.
  ///
  /// In en, this message translates to:
  /// **'Permanently erase your data. This can\'t be undone.'**
  String get privacyDeleteBody;

  /// Button/title label for deleting the account. Reused across the privacy screen and the delete-account screen (AppBar title + submit button).
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get privacyDeleteAccountButton;

  /// Confirmation dialog title shown when turning off the email_transactional consent.
  ///
  /// In en, this message translates to:
  /// **'Turn off service emails?'**
  String get privacyTurnOffEmailsDialogTitle;

  /// Confirmation dialog body shown when turning off the email_transactional consent.
  ///
  /// In en, this message translates to:
  /// **'You won\'t receive emails about your applications, matches, or account. Are you sure?'**
  String get privacyTurnOffEmailsDialogBody;

  /// Confirm button label for turning off the email_transactional consent.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get privacyTurnOffButton;

  /// Snackbar shown after a successful DSR data export.
  ///
  /// In en, this message translates to:
  /// **'Your data is on your clipboard.\nPaste it into a text editor and save as a .json file.'**
  String get privacyExportSuccessSnackbar;

  /// Snackbar shown when a DSR data export fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export your data. Try again.'**
  String get privacyExportErrorSnackbar;

  /// Snackbar shown when the delete-account submission fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Try again.'**
  String get deleteAccountErrorSnackbar;

  /// Warning banner at the top of the delete-account screen.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your personal data on Jobify. This action is irreversible.'**
  String get deleteAccountWarningBanner;

  /// Heading above the delete-account consequence bullets.
  ///
  /// In en, this message translates to:
  /// **'What will happen:'**
  String get deleteAccountWhatWillHappenHeading;

  /// First delete-account consequence bullet.
  ///
  /// In en, this message translates to:
  /// **'Your profile, resume, applications, and saved jobs are removed.'**
  String get deleteAccountBulletProfile;

  /// Second delete-account consequence bullet.
  ///
  /// In en, this message translates to:
  /// **'Your match history and notifications are erased.'**
  String get deleteAccountBulletMatchHistory;

  /// Third delete-account consequence bullet.
  ///
  /// In en, this message translates to:
  /// **'Anonymized employer-side analytics survive (apply counts only).'**
  String get deleteAccountBulletAnalytics;

  /// Hint text below the download-my-data button on the delete-account screen.
  ///
  /// In en, this message translates to:
  /// **'Before you continue, we recommend downloading your data.'**
  String get deleteAccountDownloadHint;

  /// Prompt above the confirmation text field. {phrase} is the literal wire token 'DELETE_MY_ACCOUNT', which is never translated — the user must type that exact English text; non-English locales should make this explicit in the surrounding sentence.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type {phrase} below:'**
  String deleteAccountConfirmPrompt(String phrase);

  /// Final confirmation dialog title before deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Are you absolutely sure?'**
  String get deleteAccountConfirmDialogTitle;

  /// Final confirmation dialog body before deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Your account and all associated data will be permanently deleted.'**
  String get deleteAccountConfirmDialogBody;

  /// Confirm button label in the final delete-account dialog.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete'**
  String get deleteAccountYesDeleteButton;

  /// Error message shown when the picked résumé file type isn't supported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type (PDF, DOC, DOCX).'**
  String get resumeUnsupportedFileType;

  /// Error message shown when the uploaded résumé exceeds the size limit.
  ///
  /// In en, this message translates to:
  /// **'File too large (max 10 MB).'**
  String get resumeFileTooLarge;

  /// Error message shown when a résumé upload fails due to a network error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Jobify.'**
  String get resumeNetworkError;

  /// Fallback error message shown when a résumé upload fails for an unrecognised reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload. Try again.'**
  String get resumeUploadFailedGeneric;

  /// Résumé screen AppBar title. Reused as the profile screen's résumé row title.
  ///
  /// In en, this message translates to:
  /// **'Résumé'**
  String get resumeTitle;

  /// Upload button label while an upload is in flight.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get resumeUploadingButton;

  /// Upload button label when idle.
  ///
  /// In en, this message translates to:
  /// **'Upload / Replace résumé'**
  String get resumeUploadButton;

  /// Empty-state body shown when the applicant has no résumé.
  ///
  /// In en, this message translates to:
  /// **'No résumé yet. Upload one so we can match you to roles.'**
  String get resumeEmptyBody;

  /// Résumé status chip label once parsing succeeds.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get resumeStatusReady;

  /// Résumé status chip label when parsing fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t parse — try again'**
  String get resumeStatusFailed;

  /// Résumé status chip label while parsing is pending or in progress.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get resumeStatusProcessing;

  /// Résumé card caption showing when it was uploaded — {when} is a pre-formatted date.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {when}'**
  String resumeUploadedOn(String when);

  /// Preferences screen AppBar title.
  ///
  /// In en, this message translates to:
  /// **'What are you looking for?'**
  String get preferencesTitle;

  /// Button to skip the preferences capture flow.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get preferencesSkipButton;

  /// Error text shown when the initial preferences fetch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your preferences.'**
  String get preferencesLoadError;

  /// Section heading above the preferences form.
  ///
  /// In en, this message translates to:
  /// **'Your preferences'**
  String get preferencesSectionHeading;

  /// Label for the desired-role dropdown/field. Reused on the preferences screen, edit-profile screen, and profile spec sheet.
  ///
  /// In en, this message translates to:
  /// **'Desired role'**
  String get preferencesDesiredRoleLabel;

  /// Dropdown item that clears the desired-role selection. Reused on the preferences and edit-profile screens.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get preferencesNoPreferenceOption;

  /// Label for the locations field/list. Reused on the preferences screen, edit-profile screen, and profile spec sheet.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get preferencesLocationsLabel;

  /// Label for the add-location text field. Reused on the preferences and edit-profile screens.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get preferencesAddLocationLabel;

  /// Label for the expected-CTC field. Reused on the preferences and edit-profile screens.
  ///
  /// In en, this message translates to:
  /// **'Expected CTC (₹/yr)'**
  String get preferencesExpectedCtcLabel;

  /// Body text shown on the preferences screen's résumé summary card when parsing produced no data.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read your résumé — tell us directly below.'**
  String get preferencesResumeUnparsedBody;

  /// Heading on the preferences screen's résumé summary card when parsed data is available.
  ///
  /// In en, this message translates to:
  /// **'Your résumé'**
  String get preferencesResumeHeading;

  /// Generic save-failure snackbar. Reused by the preferences and edit-profile screens.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get formSaveFailedGeneric;

  /// Display label for the software_engineering desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Software Engineering'**
  String get desiredRoleSoftwareEngineering;

  /// Display label for the data_analytics desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Data & Analytics'**
  String get desiredRoleDataAnalytics;

  /// Display label for the product_management desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Product Management'**
  String get desiredRoleProductManagement;

  /// Display label for the design desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get desiredRoleDesign;

  /// Display label for the sales desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get desiredRoleSales;

  /// Display label for the marketing desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Marketing'**
  String get desiredRoleMarketing;

  /// Display label for the customer_support desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Customer Support'**
  String get desiredRoleCustomerSupport;

  /// Display label for the operations desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get desiredRoleOperations;

  /// Display label for the finance_accounting desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Finance & Accounting'**
  String get desiredRoleFinanceAccounting;

  /// Display label for the hr_recruiting desired-role category.
  ///
  /// In en, this message translates to:
  /// **'HR & Recruiting'**
  String get desiredRoleHrRecruiting;

  /// Display label for the legal desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get desiredRoleLegal;

  /// Display label for the consulting desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Consulting'**
  String get desiredRoleConsulting;

  /// Display label for the business_development desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Business Development'**
  String get desiredRoleBusinessDevelopment;

  /// Display label for the content_communications desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Content & Communications'**
  String get desiredRoleContentCommunications;

  /// Display label for the administration desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get desiredRoleAdministration;

  /// Display label for the other desired-role category.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get desiredRoleOther;

  /// Fallback display label for an unrecognised desired-role wire value. Should never reach the UI.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get desiredRoleUnknown;

  /// Profile screen header title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Button that navigates to the edit-profile screen.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEditButton;

  /// Title of the card prompting an applicant to create an employer and start recruiting.
  ///
  /// In en, this message translates to:
  /// **'I\'m hiring — post a job'**
  String get profileHiringCtaTitle;

  /// Subtitle of the card prompting an applicant to create an employer and start recruiting.
  ///
  /// In en, this message translates to:
  /// **'Create your company to start recruiting'**
  String get profileHiringCtaSubtitle;

  /// Heading above the match-profile spec sheet on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Match profile'**
  String get profileMatchProfileHeading;

  /// Subtitle of the résumé row on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Manage your résumé'**
  String get profileResumeSubtitle;

  /// Subtitle of the notifications row on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'View your notifications'**
  String get profileNotificationsSubtitle;

  /// Subtitle of the pending-invitations row on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Company invites to recruit'**
  String get profileInvitesSubtitle;

  /// Subtitle of the privacy row on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Preferences, export, delete'**
  String get profilePrivacySubtitle;

  /// Heading above the light/dark/system theme selector.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get profileAppearanceHeading;

  /// Segmented-button label for following the system theme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get profileAppearanceSystem;

  /// Segmented-button label for the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get profileAppearanceLight;

  /// Segmented-button label for the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get profileAppearanceDark;

  /// Heading above the English/Hindi language switcher.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguageLabel;

  /// Segmented-button label for English. A language's own name renders in that language, so this value is identical in every ARB file.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get profileLanguageEnglish;

  /// Segmented-button label for Hindi. A language's own name renders in that language, so this value is identical in every ARB file.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get profileLanguageHindi;

  /// Sign-out button label while the sign-out request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get profileSigningOutButton;

  /// Sign-out button label when idle. Reused as the confirmation dialog's title question and confirm button.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOutButton;

  /// Confirmation dialog title before signing out.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get profileSignOutDialogTitle;

  /// Confirmation dialog body before signing out.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to continue.'**
  String get profileSignOutDialogBody;

  /// Row label shown on the profile spec sheet when the preferences fetch failed.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profileRetryPreferencesLabel;

  /// Spec-sheet row label for years of experience on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get profileExperienceLabel;

  /// Spec-sheet row label for notice period on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Notice period'**
  String get profileNoticePeriodLabel;

  /// Spec-sheet row value for notice period, in days.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{{days} day} other{{days} days}}'**
  String profileNoticePeriodDaysValue(int days);

  /// Spec-sheet row label for current CTC on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Current CTC'**
  String get profileCurrentCtcLabel;

  /// Spec-sheet row label for expected CTC on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Expected CTC'**
  String get profileExpectedCtcLabel;

  /// Inline error text shown next to a failed spec-sheet row's retry button.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load'**
  String get profileRetryFailedLabel;

  /// Tappable prompt shown in place of a missing spec-sheet value, jumping to edit-profile.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get profileAddFieldAction;

  /// Spec-sheet row value for years of experience — {years} is the pre-trimmed numeric string (trailing .0 dropped).
  ///
  /// In en, this message translates to:
  /// **'{years} yrs'**
  String profileYearsExperienceSuffix(String years);

  /// App version/build stamp at the bottom of the profile screen. Version numbering notation is not natural language, so this value is identical in every ARB file.
  ///
  /// In en, this message translates to:
  /// **'v{version} ({build})'**
  String profileVersionLabel(String version, String build);

  /// Edit-profile screen AppBar title.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// Error text shown when the initial profile/preferences fetch fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile.'**
  String get editProfileLoadError;

  /// Section heading for the personal-details card on the edit-profile screen.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get editProfileAboutYouHeading;

  /// Label for the full-name field.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get editProfileFullNameLabel;

  /// Validation error when the full-name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get editProfileRequiredValidation;

  /// Validation error when the full-name field exceeds 200 characters.
  ///
  /// In en, this message translates to:
  /// **'Too long (max 200)'**
  String get editProfileTooLongValidation;

  /// Snackbar shown when an entered location exceeds the character limit.
  ///
  /// In en, this message translates to:
  /// **'Location too long (max 100 chars).'**
  String get editProfileLocationTooLong;

  /// Snackbar shown when the applicant tries to add an 11th location.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 locations.'**
  String get editProfileLocationsLimitReached;

  /// Section heading for the numeric-fields card on the edit-profile screen.
  ///
  /// In en, this message translates to:
  /// **'The numbers'**
  String get editProfileTheNumbersHeading;

  /// Label for the years-of-experience field.
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get editProfileYearsExperienceLabel;

  /// Label for the notice-period field.
  ///
  /// In en, this message translates to:
  /// **'Notice period (days)'**
  String get editProfileNoticePeriodLabel;

  /// Label for the current-CTC field.
  ///
  /// In en, this message translates to:
  /// **'Current CTC (₹/yr)'**
  String get editProfileCurrentCtcLabel;

  /// Validation error when a numeric field can't be parsed.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get editProfileEnterNumberValidation;

  /// Validation error when a numeric field is outside its allowed range.
  ///
  /// In en, this message translates to:
  /// **'Must be between {min} and {max}'**
  String editProfileRangeValidation(num min, num max);

  /// Validation error when a whole-number-only field has decimal places.
  ///
  /// In en, this message translates to:
  /// **'Whole number only'**
  String get editProfileWholeNumberValidation;

  /// Validation error when a numeric field has more decimal places than allowed.
  ///
  /// In en, this message translates to:
  /// **'{maxDecimals, plural, one{At most {maxDecimals} decimal place} other{At most {maxDecimals} decimal places}}'**
  String editProfileDecimalPlacesValidation(int maxDecimals);

  /// Snackbar shown when the profile PATCH succeeds but the preferences PATCH fails.
  ///
  /// In en, this message translates to:
  /// **'Saved your profile, but couldn\'t save preferences. Try again.'**
  String get editProfileSavedProfileOnly;

  /// Snackbar shown when the preferences PATCH succeeds but the profile PATCH fails.
  ///
  /// In en, this message translates to:
  /// **'Saved your preferences, but couldn\'t save your profile. Try again.'**
  String get editProfileSavedPreferencesOnly;

  /// Pending-invitations screen AppBar title. Reused as the profile screen's invitations row title.
  ///
  /// In en, this message translates to:
  /// **'Pending invitations'**
  String get invitesTitle;

  /// Empty-state headline shown when the applicant has no pending invitations.
  ///
  /// In en, this message translates to:
  /// **'No invitations'**
  String get invitesEmptyHeadline;

  /// Empty-state body shown when the applicant has no pending invitations.
  ///
  /// In en, this message translates to:
  /// **'When a company invites you to recruit, it\'ll show up here.'**
  String get invitesEmptyBody;

  /// Invite card subtitle when the invited role is owner — {expires} is a pre-formatted date.
  ///
  /// In en, this message translates to:
  /// **'Invited as owner · expires {expires}'**
  String invitesCardSubtitleOwner(String expires);

  /// Invite card subtitle when the invited role is member — {expires} is a pre-formatted date.
  ///
  /// In en, this message translates to:
  /// **'Invited as member · expires {expires}'**
  String invitesCardSubtitleMember(String expires);

  /// Button to decline a pending invitation.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get invitesDeclineButton;

  /// Button to accept a pending invitation.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get invitesAcceptButton;

  /// Snackbar shown after successfully accepting an invitation.
  ///
  /// In en, this message translates to:
  /// **'You joined {employerName}.'**
  String invitesJoinedSnackbar(String employerName);

  /// Snackbar shown when accepting an invitation fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t accept the invitation.'**
  String get invitesAcceptErrorSnackbar;

  /// Snackbar shown when declining an invitation fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t decline the invitation.'**
  String get invitesDeclineErrorSnackbar;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
