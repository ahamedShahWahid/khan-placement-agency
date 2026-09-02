import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/data/me/me_dto.dart';
import 'package:jobify_app/data/me/profile_update_dto.dart';
import 'package:jobify_app/data/preferences/desired_role.dart';
import 'package:jobify_app/data/preferences/preferences_dto.dart';
import 'package:jobify_app/data/preferences/preferences_update_dto.dart';
import 'package:jobify_app/l10n/app_localizations.dart';
import 'package:jobify_app/presentation/preferences/desired_role_label.dart';
import 'package:jobify_app/presentation/preferences/preferences_controller.dart';
import 'package:jobify_app/presentation/profile/me_controller.dart';
import 'package:jobify_app/presentation/profile/profile_edit_controller.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';
import 'package:jobify_app/presentation/theme/jobify_typography.dart';
import 'package:jobify_app/presentation/widgets/jobify_match_chip.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _experience = TextEditingController();
  final _notice = TextEditingController();
  final _currentCtc = TextEditingController();
  final _expectedCtc = TextEditingController();
  final _locationInput = TextEditingController();
  List<String> _locations = [];
  DesiredRole? _desiredRole;
  String _language = 'en';
  bool _seeded = false;

  /// One-shot seed from resolved data (mirrors PreferencesScreen's
  /// `_seedFromPreferences`). Never called with unresolved providers — the
  /// old eager `initState` read `.value` while preferences could still be
  /// loading, seeding `_locations = []` and silently wiping the saved
  /// locations server-side on the next Save.
  void _seed(ApplicantSummaryDto? a, PreferencesDto prefs) {
    _seeded = true;
    _fullName.text = a?.fullName ?? '';
    _experience.text = a?.yearsExperience ?? '';
    _notice.text = a?.noticePeriodDays?.toString() ?? '';
    _currentCtc.text = a?.currentCtc ?? '';
    _expectedCtc.text = prefs.expectedCtc ?? '';
    _locations = List<String>.from(prefs.locations);
    // Keep the raw seeded value INCLUDING `unknown`: an untouched unknown
    // is omitted on save, preserving the server's (newer-than-this-build)
    // role instead of clearing it.
    _desiredRole = prefs.desiredRole;
    // No language switcher on this screen — carry the current value through
    // unchanged (PreferencesUpdateDto is full-form and always sends it).
    _language = prefs.language;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _experience.dispose();
    _notice.dispose();
    _currentCtc.dispose();
    _expectedCtc.dispose();
    _locationInput.dispose();
    super.dispose();
  }

  void _addLocation() {
    final v = _locationInput.text.trim();
    if (v.isEmpty || _locations.contains(v)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (v.length > 100) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.editProfileLocationTooLong)),
      );
      return;
    }
    if (_locations.length >= 10) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.editProfileLocationsLimitReached)),
      );
      return;
    }
    setState(() {
      _locations.add(v);
      _locationInput.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profileUpdate = ProfileUpdateDto(
      fullName: _fullName.text.trim(),
      noticePeriodDays: int.tryParse(_notice.text.trim()),
      currentCtc: num.tryParse(_currentCtc.text.trim()),
      yearsExperience: num.tryParse(_experience.text.trim()),
    );
    final preferencesUpdate = PreferencesUpdateDto(
      desiredRole: _desiredRole,
      locations: _locations,
      expectedCtc: num.tryParse(_expectedCtc.text.trim()),
      language: _language,
    );
    final profileOk = await ref
        .read(profileEditControllerProvider.notifier)
        .submit(profileUpdate);
    final prefsOk = await ref
        .read(preferencesControllerProvider.notifier)
        .submit(preferencesUpdate);
    if (!mounted) return;
    if (profileOk && prefsOk) {
      if (context.canPop()) context.pop();
      return;
    }
    // Two sequential PATCHes can partially succeed — say which half failed.
    final l10n = context.l10n;
    final message =
        profileOk
            ? l10n.editProfileSavedProfileOnly
            : prefsOk
            ? l10n.editProfileSavedPreferencesOnly
            : l10n.formSaveFailedGeneric;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meControllerProvider);
    final prefs = ref.watch(preferencesControllerProvider);
    final l10n = context.l10n;

    if (!_seeded) {
      if (me.hasValue && prefs.hasValue) {
        _seed(me.requireValue.applicant, prefs.requireValue);
      } else {
        // The form (and Save) must be unreachable until seeded from real
        // data — saving a half-seeded form would wipe server-side values.
        final meFailed = me.hasError && !me.hasValue;
        final prefsFailed = prefs.hasError && !prefs.hasValue;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.editProfileTitle)),
          body: Center(
            child:
                meFailed || prefsFailed
                    ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.editProfileLoadError),
                        const SizedBox(height: JobifySpacing.sm),
                        TextButton(
                          onPressed: () {
                            if (meFailed) ref.invalidate(meControllerProvider);
                            if (prefsFailed) {
                              ref.invalidate(preferencesControllerProvider);
                            }
                          },
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    )
                    : const CircularProgressIndicator(),
          ),
        );
      }
    }

    final theme = Theme.of(context);
    final saving =
        ref.watch(profileEditControllerProvider).isLoading || prefs.isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfileTitle),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? l10n.commonSaving : l10n.commonSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(JobifySpacing.lg),
          children: [
            Text(
              l10n.editProfileAboutYouHeading,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: JobifySpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(JobifySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _fullName,
                      decoration: InputDecoration(
                        labelText: l10n.editProfileFullNameLabel,
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) {
                          return l10n.editProfileRequiredValidation;
                        }
                        if (t.length > 200) {
                          return l10n.editProfileTooLongValidation;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: JobifySpacing.lg),
                    DropdownButtonFormField<DesiredRole>(
                      // `unknown` (unrecognised server value) has no menu
                      // item; show it as no selection. `_desiredRole` keeps
                      // the raw `unknown` until the user picks something, so
                      // an untouched save omits the key and preserves the
                      // server value.
                      initialValue:
                          _desiredRole == DesiredRole.unknown
                              ? null
                              : _desiredRole,
                      decoration: InputDecoration(
                        labelText: l10n.preferencesDesiredRoleLabel,
                      ),
                      items: [
                        // A null item so a previously set role can be
                        // CLEARED.
                        DropdownMenuItem<DesiredRole>(
                          child: Text(l10n.preferencesNoPreferenceOption),
                        ),
                        for (final role in DesiredRole.values.where(
                          (r) => r != DesiredRole.unknown,
                        ))
                          DropdownMenuItem(
                            value: role,
                            child: Text(desiredRoleLabel(context, role)),
                          ),
                      ],
                      onChanged: (role) => setState(() => _desiredRole = role),
                    ),
                    const SizedBox(height: JobifySpacing.lg),
                    Text(
                      l10n.preferencesLocationsLabel,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: JobifySpacing.sm),
                    if (_locations.isNotEmpty) ...[
                      Wrap(
                        spacing: JobifySpacing.sm,
                        runSpacing: JobifySpacing.sm,
                        children: [
                          for (final loc in _locations)
                            JobifyMatchChip(
                              label: loc,
                              onDeleted:
                                  () => setState(() => _locations.remove(loc)),
                            ),
                        ],
                      ),
                      const SizedBox(height: JobifySpacing.sm),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationInput,
                            decoration: InputDecoration(
                              labelText: l10n.preferencesAddLocationLabel,
                            ),
                            onSubmitted: (_) => _addLocation(),
                          ),
                        ),
                        IconButton(
                          onPressed: _addLocation,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: JobifySpacing.xl),
            Text(
              l10n.editProfileTheNumbersHeading,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: JobifySpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(JobifySpacing.lg),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _experience,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: JobifyTypography.mono(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.editProfileYearsExperienceLabel,
                      ),
                      validator:
                          (v) => _validateOptionalNumber(
                            v,
                            l10n,
                            min: 0,
                            max: 60,
                            maxDecimals: 1,
                          ),
                    ),
                    const SizedBox(height: JobifySpacing.lg),
                    TextFormField(
                      controller: _notice,
                      keyboardType: TextInputType.number,
                      style: JobifyTypography.mono(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.editProfileNoticePeriodLabel,
                      ),
                      validator:
                          (v) => _validateOptionalNumber(
                            v,
                            l10n,
                            min: 0,
                            max: 365,
                            maxDecimals: 0,
                          ),
                    ),
                    const SizedBox(height: JobifySpacing.lg),
                    TextFormField(
                      controller: _currentCtc,
                      keyboardType: TextInputType.number,
                      style: JobifyTypography.mono(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.editProfileCurrentCtcLabel,
                      ),
                      validator:
                          (v) => _validateOptionalNumber(
                            v,
                            l10n,
                            min: 0,
                            max: 9999999999.99,
                            maxDecimals: 2,
                          ),
                    ),
                    const SizedBox(height: JobifySpacing.lg),
                    TextFormField(
                      controller: _expectedCtc,
                      keyboardType: TextInputType.number,
                      style: JobifyTypography.mono(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.preferencesExpectedCtcLabel,
                      ),
                      validator:
                          (v) => _validateOptionalNumber(
                            v,
                            l10n,
                            min: 0,
                            max: 9999999999.99,
                            maxDecimals: 2,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Validate an optional numeric form field against the backend's bounds.
/// Empty is allowed (the field clears). Returns an error message, or null when
/// valid. `maxDecimals` mirrors the column scale (e.g. Numeric(4,1) → 1) so the
/// user is told instead of the DB silently rounding.
String? _validateOptionalNumber(
  String? raw,
  AppLocalizations l10n, {
  required num min,
  required num max,
  required int maxDecimals,
}) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return null;
  final n = num.tryParse(t);
  if (n == null) return l10n.editProfileEnterNumberValidation;
  if (n < min || n > max) return l10n.editProfileRangeValidation(min, max);
  final dot = t.indexOf('.');
  if (dot >= 0 && t.length - dot - 1 > maxDecimals) {
    return maxDecimals == 0
        ? l10n.editProfileWholeNumberValidation
        : l10n.editProfileDecimalPlacesValidation(maxDecimals);
  }
  return null;
}
