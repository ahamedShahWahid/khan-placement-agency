import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jobify_app/l10n/app_localizations.dart';
import 'package:jobify_app/presentation/routing/locale_controller.dart';
import 'package:jobify_app/presentation/routing/router.dart';
import 'package:jobify_app/presentation/theme/build_theme.dart';
import 'package:jobify_app/presentation/theme/theme_mode_controller.dart';

class JobifyApp extends ConsumerWidget {
  const JobifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      title: 'Jobify',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == deviceLocale.languageCode) {
              return supported;
            }
          }
        }
        return const Locale('en');
      },
    );
  }
}
