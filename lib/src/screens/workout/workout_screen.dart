import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_workout_screen.dart';
import 'edit_workout_screen.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});
  @override State<WorkoutScreen> createState() => _WorkoutScreenState();
}
class _WorkoutScreenState extends State<WorkoutScreen> {
  String _filter = 'All';
  bool _showExercises = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  static const _filters = ['All', 'Strength', 'Cardio', 'Full Body'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        final filtered = all.where((w) {
          final matchesCategory = _filter == 'All' || (_filter == 'Full Body' ? w.category.toLowerCase() == 'strength' : w.category.toLowerCase() == _filter.toLowerCase());
          final query = _searchQuery.trim().toLowerCase();
          final matchesSearch = query.isEmpty || w.name.toLowerCase().contains(query) || w.category.toLowerCase().contains(query);
          return matchesCategory && matchesSearch;
        }).toList();
        final minutes = all.fold<int>(0, (sum, w) => sum + w.duration);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Workout', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink)), SizedBox(height: 2), Text('Track your workouts and stay consistent', style: TextStyle(fontSize: 11, color: _muted))])),
            Material(color: _lime, borderRadius: BorderRadius.circular(16), child: InkWell(onTap: _add, borderRadius: BorderRadius.circular(16), child: const SizedBox(width: 46, height: 46, child: Icon(Icons.add_rounded, color: Color(0xFF080D0B), size: 27)))),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF141B17),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _topTab(
                    'My Workouts',
                    !_showExercises,
                    () => setState(() => _showExercises = false),
                  ),
                ),
                Expanded(
                  child: _topTab(
                    'Exercises',
                    _showExercises,
                    () => setState(() => _showExercises = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(color: _ink, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search workouts...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                tooltip: 'Clear search',
                onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; }),
                icon: const Icon(Icons.close_rounded),
              ),
              filled: true,
              fillColor: const Color(0xFF141B17),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF27332B))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF27332B))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _lime)),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _filters.map((f) {
            final selected = _filter == f;
            return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f), selected: selected, onSelected: (_) => setState(() => _filter = f), backgroundColor: const Color(0xFF27332B), selectedColor: _lime, side: BorderSide.none, showCheckmark: false, shape: const StadiumBorder(), labelStyle: TextStyle(fontSize: 12, color: _ink, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)));
          }).toList())),
          const SizedBox(height: 14),
          if (!_showExercises) Row(children: [
            Expanded(child: _WorkoutStat(icon: Icons.fitness_center_rounded, label: 'Workouts', value: all.length.toString())),
            const SizedBox(width: 10),
            Expanded(child: _WorkoutStat(icon: Icons.schedule_rounded, label: 'Active minutes', value: minutes.toString())),
          ]),
          const SizedBox(height: 18),
          if (!_showExercises) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Your activity', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
            Text(filtered.length.toString() + ' workouts', style: const TextStyle(fontSize: 12, color: _muted)),
          ]),
          const SizedBox(height: 10),
          if (_showExercises)
            ..._exerciseItems.map((item) => _ExerciseCard(item: item, onAdd: _add))
          else if (filtered.isEmpty)
            const AppEmptyState(icon: Icons.fitness_center_outlined, title: 'Ready to get moving?', message: 'Add your first workout to start building your fitness history.')
          else
            ...filtered.map((w) => _WorkoutCard(workout: w)),
          const SizedBox(height: 12),
          SizedBox(height: 50, child: FilledButton.icon(onPressed: _add, style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: const Color(0xFF080D0B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.add_circle_outline_rounded), label: const Text('Add Workout', style: TextStyle(fontWeight: FontWeight.w800))),),
        ]);
      },
    )),
  );
}

class _WorkoutStat extends StatelessWidget {
  const _WorkoutStat({required this.icon, required this.label, required this.value});
  final IconData icon; final String label, value;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF27332B))), child: Row(children: [
    Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: _lime, size: 20)),
    const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)), Text(label, style: const TextStyle(fontSize: 11, color: _muted))])),
  ]));
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});
  final Workout workout;
  Future<void> _delete(BuildContext context) async {
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Delete workout?'), content: Text('Delete "' + workout.name + '" permanently?'), actions: [
      TextButton(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF5F665D)),
        onPressed: () => Navigator.of(d).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB23B3B),
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.of(d).pop(true),
        child: const Text('Delete'),
      ),
    ]));
    if (yes != true || !context.mounted) return;
    try {
      await WorkoutService.instance.deleteWorkout(workout.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete workout. Please try again.')));
    }
  }
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF27332B))), child: Row(children: [
    Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(15)), child: Icon(_workoutIcon(workout.category), color: _lime, size: 25)),
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

Widget _topTab(String label, bool selected, VoidCallback onTap) => Material(
  color: selected ? _lime : Colors.transparent,
  borderRadius: BorderRadius.circular(10),
  child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 11),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF080D0B) : _muted)))),
);

const _exerciseItems = [
  ('Push Up', 'Strength', '3 sets · 15 reps', Icons.fitness_center_rounded, 'https://images.unsplash.com/photo-1561909234-3f308b7de1b8?auto=format&fit=crop&w=240&q=80'),
  ('Squat', 'Strength', '4 sets · 12 reps', Icons.accessibility_new_rounded, 'https://images.unsplash.com/photo-1566241142559-40e1dab266c6?auto=format&fit=crop&w=240&q=80'),
  ('Bench Press', 'Strength', '4 sets · 10 reps', Icons.fitness_center_rounded, 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=240&q=80'),
  ('Plank', 'Full Body', '3 sets · 60 sec', Icons.self_improvement_rounded, 'https://images.unsplash.com/photo-1566241142559-40e1dab266c6?auto=format&fit=crop&w=240&q=80'),
  ('Running', 'Cardio', '30 min', Icons.directions_run_rounded, 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?auto=format&fit=crop&w=240&q=80'),
];

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.item, required this.onAdd});
  final (String, String, String, IconData, String) item;
  final VoidCallback onAdd;
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF202B24))),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          item.$5,
          width: 58,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 58,
            height: 48,
            color: const Color(0xFF25351D),
            child: Icon(item.$4, color: _lime, size: 22),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 3),
        Text(item.$3, style: const TextStyle(fontSize: 10, color: _muted)),
      ])),
      IconButton(onPressed: onAdd, icon: const Icon(Icons.play_circle_outline_rounded, color: _lime, size: 24), tooltip: 'Log workout'),
    ]),
  );
}
