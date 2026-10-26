import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final profile = UserProfile(
      uid: widget.profile.uid,
      email: widget.profile.email,
      displayName: _nameController.text.trim(),
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
      if (profile.weightKg != null && profile.weightKg != widget.profile.weightKg) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(profile.uid)
            .collection('weightEntries')
            .add({
          'weightKg': profile.weightKg,
          'recordedAt': FieldValue.serverTimestamp(),
        });
      }
      // Keep Firebase Authentication's display name in sync with the saved profile.
      final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (authUser != null && authUser.displayName != profile.displayName) {
        await authUser.updateDisplayName(profile.displayName);
        await authUser.reload();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save your profile.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF080D0B),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFF4F7F1)))),
                      IconButton(
                        tooltip: 'Account settings',
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can update your personal details below.'))),
                        icon: const Icon(Icons.settings_outlined, color: Color(0xFF232824)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF25351D),
                          child: Text(
                            _nameController.text.trim().isEmpty ? 'U' : _nameController.text.trim()[0].toUpperCase(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF232824)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_nameController.text.trim().isEmpty ? 'FitTrack member' : _nameController.text.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF232824))),
                            const SizedBox(height: 4),
                            Text(widget.profile.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF9AA69C))),
                            const SizedBox(height: 7),
                            const Text('Edit Profile', style: TextStyle(fontSize: 12, color: Color(0xFF6AAE20), fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Personal details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF232824))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Display name', prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name.' : null,
                        ),
                        const SizedBox(height: 13),
                        DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_rounded)),
                          items: _genders.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (value) => setState(() => _gender = value),
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined)),
                          validator: (value) => value != null && value.isNotEmpty && int.tryParse(value) == null ? 'Enter a valid age.' : null,
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Height (cm)', prefixIcon: Icon(Icons.height_rounded)),
                          validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Enter a valid height.' : null,
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Weight (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined)),
                          validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Enter a valid weight.' : null,
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: _targetWeightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Target weight (kg)', prefixIcon: Icon(Icons.flag_circle_outlined), helperText: 'Optional — used to track your weight goal.'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return null;
                            final weight = double.tryParse(value.trim());
                            return weight == null || weight < 20 || weight > 400 ? 'Enter a target between 20 and 400 kg.' : null;
                          },
                        ),
                        const SizedBox(height: 13),
                        DropdownButtonFormField<String>(
                          value: _fitnessGoal,
                          decoration: const InputDecoration(labelText: 'Fitness goal', prefixIcon: Icon(Icons.flag_outlined)),
                          items: _goals.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (value) => setState(() => _fitnessGoal = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(_isSaving ? 'Saving...' : 'Save profile'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => FirebaseAuthService.instance.signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB23B3B),
                        backgroundColor: const Color(0xFFFBE6E4),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
