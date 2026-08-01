import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobify_app/core/error/exceptions.dart';
import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/presentation/onboarding/employer_onboarding_controller.dart';

class EmployerOnboardingScreen extends ConsumerStatefulWidget {
  const EmployerOnboardingScreen({super.key});

  @override
  ConsumerState<EmployerOnboardingScreen> createState() =>
      _EmployerOnboardingScreenState();
}

class _EmployerOnboardingScreenState
    extends ConsumerState<EmployerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gst = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _gst.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 2) return context.l10n.onboardingCompanyNameTooShort;
    if (s.length > 200) return context.l10n.onboardingCompanyNameTooLong;
    return null;
  }

  String? _validateGst(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (s.length != 15) return context.l10n.onboardingGstinLength;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(employerOnboardingControllerProvider.notifier).submit(
          name: _name.text.trim(),
          gst: _gst.text.trim().isEmpty ? null : _gst.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employerOnboardingControllerProvider);
    final isLoading = state.isLoading;

    ref.listen(employerOnboardingControllerProvider, (_, next) {
      if (next.hasError && context.mounted) {
        final err = next.error;
        final msg = err is ApiException && err.slug == 'employer_name_taken'
            ? context.l10n.onboardingCompanyNameTaken
            : context.l10n.onboardingCreateEmployerFailed;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.onboardingTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.onboardingIntro),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.l10n.onboardingCompanyNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gst,
                decoration: InputDecoration(
                  labelText: context.l10n.onboardingGstinLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: _validateGst,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.onboardingCreateCompanyButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
