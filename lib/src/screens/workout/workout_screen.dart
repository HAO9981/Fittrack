import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_workout_screen.dart';
import 'edit_workout_screen.dart';

const _lime = Color(0xFF84E221);
const _ink = Color(0xFF232824);
const _muted = Color(0xFF858C83);
const _bg = Color(0xFFF6F7F4);

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});
  @override State<WorkoutScreen> createState() => _WorkoutScreenState();
}
class _WorkoutScreenState extends State<WorkoutScreen> {
  String _filter = 'All';
  static const _filters = ['All', 'Strength', 'Cardio', 'Flexibility', 'HIIT'];

  void _add() {
    if (FirebaseAuthService.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to add a workout.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddWorkoutScreen()));
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(child: StreamBuilder<List<Workout>>(
      stream: WorkoutService.instance.getWorkouts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _lime));
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.error is StateError ? 'Please sign in to view your workouts.' : 'Unable to load workouts. Please try again.', textAlign: TextAlign.center)));
        final all = snapshot.data ?? <Workout>[];
        final filtered = _filter == 'All' ? all : all.where((w) => w.category.toLowerCase() == _filter.toLowerCase()).toList();
        final minutes = all.fold<int>(0, (sum, w) => sum + w.duration);
        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 100), children: [
          Row(children: [
            const Expanded(child: Text('Workouts', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink))),
            Material(color: _lime, borderRadius: BorderRadius.circular(17), child: InkWell(onTap: _add, borderRadius: BorderRadius.circular(17), child: const SizedBox(width: 48, height: 48, child: Icon(Icons.add_rounded, color: _ink, size: 28)))),
          ]),
          const SizedBox(height: 17),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _filters.map((f) {
            final selected = _filter == f;
            return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f), selected: selected, onSelected: (_) => setState(() => _filter = f), backgroundColor: const Color(0xFFE9ECE6), selectedColor: _lime, side: BorderSide.none, showCheckmark: false, shape: const StadiumBorder(), labelStyle: TextStyle(fontSize: 12, color: _ink, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)));
          }).toList())),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _WorkoutStat(icon: Icons.fitness_center_rounded, label: 'Workouts', value: all.length.toString())),
            const SizedBox(width: 10),
            Expanded(child: _WorkoutStat(icon: Icons.schedule_rounded, label: 'Active minutes', value: minutes.toString())),
          ]),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Your activity', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
            Text(filtered.length.toString() + ' workouts', style: const TextStyle(fontSize: 12, color: _muted)),
          ]),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            const AppEmptyState(icon: Icons.fitness_center_outlined, title: 'Ready to get moving?', message: 'Add your first workout to start building your fitness history.')
          else
            ...filtered.map((w) => _WorkoutCard(workout: w)),
        ]);
      },
    )),
  );
}

class _WorkoutStat extends StatelessWidget {
  const _WorkoutStat({required this.icon, required this.label, required this.value});
  final IconData icon; final String label, value;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Row(children: [
    Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFF0F6E9), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: _ink, size: 20)),
    const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)), Text(label, style: const TextStyle(fontSize: 11, color: _muted))])),
  ]));
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});
  final Workout workout;
  Future<void> _delete(BuildContext context) async {
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Delete workout?'), content: Text('Delete "' + workout.name + '" permanently?'), actions: [
      TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Delete')),
    ]));
    if (yes != true || !context.mounted) return;
    try {
      await WorkoutService.instance.deleteWorkout(workout.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete workout. Please try again.')));
    }
  }
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21)), child: Row(children: [
    Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFF0F3EC), borderRadius: BorderRadius.circular(17)), child: Icon(_workoutIcon(workout.category), color: _ink, size: 25)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(workout.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
      const SizedBox(height: 4), Text(workout.category, style: const TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 7), Row(children: [const Icon(Icons.schedule_rounded, size: 13, color: _muted), const SizedBox(width: 4), Text(workout.duration.toString() + ' mins', style: const TextStyle(fontSize: 11, color: _muted)), const SizedBox(width: 10), Flexible(child: Text(MaterialLocalizations.of(context).formatMediumDate(workout.date), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _muted)))]),
    ])),
    PopupMenuButton<String>(icon: const Icon(Icons.more_horiz_rounded, color: _ink), onSelected: (v) {
      if (v == 'edit') Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditWorkoutScreen(workout: workout)));
      if (v == 'delete') _delete(context);
    }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit workout')), PopupMenuItem(value: 'delete', child: Text('Delete workout'))]),
  ]));
}

IconData _workoutIcon(String category) => switch (category) {
  'Cardio' => Icons.directions_run_rounded,
  'Flexibility' => Icons.self_improvement_rounded,
  'HIIT' => Icons.bolt_rounded,
  'Strength' => Icons.fitness_center_rounded,
  _ => Icons.sports_gymnastics_rounded,
};
