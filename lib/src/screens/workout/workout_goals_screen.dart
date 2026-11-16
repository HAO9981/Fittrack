import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _surface = Color(0xFF141B17);

class WorkoutGoalsScreen extends StatefulWidget {
  const WorkoutGoalsScreen({super.key});
  @override
  State<WorkoutGoalsScreen> createState() => _WorkoutGoalsScreenState();
}

class _WorkoutGoalsScreenState extends State<WorkoutGoalsScreen> {
  final _sessionsController = TextEditingController(text: '3');
  final _minutesController = TextEditingController(text: '150');
  bool _loading = true;
  bool _saving = false;
  String? _error;

  DocumentReference<Map<String, dynamic>>? get _userDocument {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ref = _userDocument;
      if (ref == null) {
        setState(() => _error = 'Please sign in to manage your goals.');
        return;
      }
      final snapshot = await ref.get();
      final data = snapshot.data() ?? {};
      if (!mounted) return;
      _sessionsController.text = '${data['workoutGoalSessionsPerWeek'] ?? 3}';
      _minutesController.text = '${data['workoutGoalMinutesPerWeek'] ?? 150}';
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load your goals. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final sessions = int.tryParse(_sessionsController.text.trim());
    final minutes = int.tryParse(_minutesController.text.trim());
    if (sessions == null || sessions < 1 || sessions > 14 ||
        minutes == null || minutes < 1 || minutes > 2000) {
      setState(() => _error = 'Enter 1–14 sessions and 1–2000 minutes per week.');
      return;
    }
    final ref = _userDocument;
    if (ref == null) {
      setState(() => _error = 'Please sign in to save your goals.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.set({
        'workoutGoalSessionsPerWeek': sessions,
        'workoutGoalMinutesPerWeek': minutes,
        'workoutGoalsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout goals saved.')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save your goals. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _sessionsController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, foregroundColor: _ink, title: const Text('Workout Goals')),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: _lime))
      : ListView(padding: const EdgeInsets.all(18), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF526B3D))),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.flag_rounded, color: _lime, size: 28),
              SizedBox(height: 10),
              Text('Set a weekly target', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 18)),
              SizedBox(height: 5),
              Text('Choose realistic goals that fit your schedule. You can adjust them whenever your routine changes.', style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
            ]),
          ),
          const SizedBox(height: 18),
          _GoalInput(title: 'Workout sessions per week', hint: 'e.g. 3', controller: _sessionsController, suffix: 'sessions', icon: Icons.fitness_center_rounded),
          const SizedBox(height: 14),
          _GoalInput(title: 'Training minutes per week', hint: 'e.g. 150', controller: _minutesController, suffix: 'minutes', icon: Icons.schedule_rounded),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
          const SizedBox(height: 20),
          SizedBox(height: 50, child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: _bg),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _bg)) : const Text('Save Goals', style: TextStyle(fontWeight: FontWeight.w800)),
          )),
          const SizedBox(height: 12),
          const Text('Goals are stored in your FitTrack user profile and used to calculate weekly progress.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 10)),
        ]),
  );
}

class _GoalInput extends StatelessWidget {
  const _GoalInput({required this.title, required this.hint, required this.controller, required this.suffix, required this.icon});
  final String title, hint, suffix;
  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF27332B))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: _lime, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13))]),
      const SizedBox(height: 12),
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700),
        decoration: InputDecoration(hintText: hint, suffixText: suffix, filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      ),
    ]),
  );
}
