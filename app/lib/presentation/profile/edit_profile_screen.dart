import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kpa_app/data/me/profile_update_dto.dart';
import 'package:kpa_app/presentation/profile/me_controller.dart';
import 'package:kpa_app/presentation/profile/profile_edit_controller.dart';
import 'package:kpa_app/presentation/theme/kpa_spacing.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _experience;
  late final TextEditingController _notice;
  late final TextEditingController _currentCtc;
  late final TextEditingController _expectedCtc;
  final _locationInput = TextEditingController();
  late List<String> _locations;

  @override
  void initState() {
    super.initState();
    final a = ref.read(meControllerProvider).value?.applicant;
    _fullName = TextEditingController(text: a?.fullName ?? '');
    _experience = TextEditingController(text: a?.yearsExperience ?? '');
    _notice =
        TextEditingController(text: a?.noticePeriodDays?.toString() ?? '');
    _currentCtc = TextEditingController(text: a?.currentCtc ?? '');
    _expectedCtc = TextEditingController(text: a?.expectedCtc ?? '');
    _locations = List<String>.from(a?.locations ?? const []);
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
    setState(() {
      _locations.add(v);
      _locationInput.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final update = ProfileUpdateDto(
      fullName: _fullName.text.trim(),
      locations: _locations,
      noticePeriodDays: int.tryParse(_notice.text.trim()),
      currentCtc: num.tryParse(_currentCtc.text.trim()),
      expectedCtc: num.tryParse(_expectedCtc.text.trim()),
      yearsExperience: num.tryParse(_experience.text.trim()),
    );
    final ok =
        await ref.read(profileEditControllerProvider.notifier).submit(update);
    if (!mounted) return;
    if (ok) {
      if (context.canPop()) context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(profileEditControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: Text(saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KpaSpacing.lg),
          children: [
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: KpaSpacing.lg),
            Text('Locations', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: KpaSpacing.sm,
              children: [
                for (final loc in _locations)
                  Chip(
                    label: Text(loc),
                    onDeleted: () => setState(() => _locations.remove(loc)),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationInput,
                    decoration:
                        const InputDecoration(labelText: 'Add location'),
                    onSubmitted: (_) => _addLocation(),
                  ),
                ),
                IconButton(
                    onPressed: _addLocation, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: KpaSpacing.lg),
            TextFormField(
              controller: _experience,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Years of experience'),
            ),
            TextFormField(
              controller: _notice,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Notice period (days)'),
            ),
            TextFormField(
              controller: _currentCtc,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Current CTC (₹/yr)'),
            ),
            TextFormField(
              controller: _expectedCtc,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Expected CTC (₹/yr)'),
            ),
          ],
        ),
      ),
    );
  }
}
