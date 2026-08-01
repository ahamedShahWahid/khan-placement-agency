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
