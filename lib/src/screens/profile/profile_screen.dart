import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_loading.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) return const AppLoading(message: 'Loading profile...');

    return StreamBuilder<UserProfile?>(
      stream: FirestoreService.instance.userProfileStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(message: 'Loading profile...');
        }
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('Unable to load your profile.')));
        }

        final profile = snapshot.data ?? UserProfile.initial(user);
        return _ProfileForm(key: ValueKey(profile.updatedAt), profile: profile);
      },
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _targetWeightController;
  late String? _gender;
  late String? _fitnessGoal;
  bool _isSaving = false;

  static const _genders = ['Female', 'Male', 'Prefer not to say'];
  static const _goals = ['Lose weight', 'Maintain fitness', 'Build muscle', 'Improve endurance'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _ageController = TextEditingController(text: widget.profile.age?.toString() ?? '');
    _heightController = TextEditingController(text: widget.profile.heightCm?.toString() ?? '');
    _weightController = TextEditingController(text: widget.profile.weightKg?.toString() ?? '');
    _targetWeightController = TextEditingController(text: widget.profile.targetWeightKg?.toString() ?? '');
    _gender = widget.profile.gender;
    _fitnessGoal = widget.profile.fitnessGoal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final displayName = _nameController.text.trim();
    final profile = UserProfile(
      uid: widget.profile.uid,
      email: widget.profile.email,
      displayName: displayName,
      gender: _gender,
      age: int.tryParse(_ageController.text),
      heightCm: double.tryParse(_heightController.text),
      weightKg: double.tryParse(_weightController.text),
      targetWeightKg: double.tryParse(_targetWeightController.text),
      fitnessGoal: _fitnessGoal,
      createdAt: widget.profile.createdAt,
    );

    try {
      await FirestoreService.instance.updateUserProfile(profile);

      if (displayName != widget.profile.displayName) {
        await FirebaseAuthService.instance.updateDisplayName(displayName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save your profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.profile.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Display name'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: _genders.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: (value) => value != null && value.isNotEmpty && int.tryParse(value) == null ? 'Enter a valid age.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Height (cm)'),
                    validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Enter a valid height.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Current weight (kg)'),
                    validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Enter a valid weight.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _targetWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Target weight (kg)'),
                    validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Enter a valid target weight.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _fitnessGoal,
                    decoration: const InputDecoration(labelText: 'Fitness goal'),
                    items: _goals.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setState(() => _fitnessGoal = value),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(_isSaving ? 'Saving...' : 'Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
