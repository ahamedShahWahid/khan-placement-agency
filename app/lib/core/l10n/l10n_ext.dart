import 'package:flutter/widgets.dart';

import 'package:jobify_app/l10n/app_localizations.dart';

/// Shorthand access to the localized strings for the current [BuildContext].
///
/// `AppLocalizations.of(context)` is non-null once
/// [AppLocalizations.localizationsDelegates] is wired into `MaterialApp` —
/// see `lib/app.dart`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
