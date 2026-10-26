import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../services/workout_category_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_workout_screen.dart';
import 'edit_workout_screen.dart';
import 'workout_categories_screen.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String _filter = 'All';
  bool _showExercises = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final Stream<List<Workout>> _workoutsStream;
  late final Stream<WorkoutCategorySettings> _categorySettingsStream;

  @override
  void initState() {
    super.initState();
    _workoutsStream = WorkoutService.instance.getWorkouts();
    _categorySettingsStream = WorkoutCategoryService.instance.watch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _add({WorkoutExercisePreset? preset}) {
    if (FirebaseAuthService.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add a workout.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddWorkoutScreen(
          initialName: preset?.name,
          initialCategory: preset?.category,
          initialSets: preset?.sets,
          initialReps: preset?.reps,
          initialDuration: preset?.duration,
          initialDurationUnit: preset?.durationUnit ?? 'minutes',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(
      child: StreamBuilder<List<Workout>>(
        stream: _workoutsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: _lime));
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error is StateError
                      ? 'Please sign in to view your workouts.'
                      : 'Unable to load workouts. Please try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          final all = snapshot.data ?? <Workout>[];
          final filtered = all.where((w) {
            final matchesCategory =
                _filter == 'All' ||
                w.category.toLowerCase() == _filter.toLowerCase();
            final query = _searchQuery.trim().toLowerCase();
            final matchesSearch =
                query.isEmpty ||
                w.name.toLowerCase().contains(query) ||
                w.category.toLowerCase().contains(query);
            return matchesCategory && matchesSearch;
          }).toList();
          final minutes = all.fold<int>(
            0,
            (sum, w) => sum + w.durationInMinutes,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workout',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track your workouts and stay consistent',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: _lime,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _add,
                      borderRadius: BorderRadius.circular(16),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.add_rounded,
                          color: Color(0xFF080D0B),
                          size: 27,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                focusNode: _searchFocusNode,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: _ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search workouts...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _searchFocusNode.requestFocus();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF141B17),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF27332B)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF27332B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _lime),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<WorkoutCategorySettings>(
                stream: _categorySettingsStream,
                builder: (context, categoriesSnapshot) {
                  final settings =
                      categoriesSnapshot.data ??
                      const WorkoutCategorySettings();
                  final available = <String>{
                    ...WorkoutCategoryService.systemCategories,
                    ...settings.custom,
                    ...all.map((workout) => workout.category),
                  };
                  final filters = [
                    'All',
                    ...available.where(
                      (category) => !settings.hidden.contains(category),
                    ),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Categories',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutCategoriesScreen(
                                  legacyCategories: all
                                      .map((w) => w.category)
                                      .toSet()
                                      .toList(),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('Edit Categories'),
                            style: TextButton.styleFrom(
                              foregroundColor: _lime,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filters.map((f) {
                            final selected = _filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: selected,
                                onSelected: (_) => setState(() => _filter = f),
                                backgroundColor: const Color(0xFF27332B),
                                selectedColor: _lime,
                                side: BorderSide.none,
                                showCheckmark: false,
                                shape: const StadiumBorder(),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? const Color(0xFF080D0B)
                                      : _ink,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              if (!_showExercises)
                Row(
                  children: [
                    Expanded(
                      child: _WorkoutStat(
                        icon: Icons.fitness_center_rounded,
                        label: 'Workouts',
                        value: all.length.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WorkoutStat(
                        icon: Icons.schedule_rounded,
                        label: 'Active minutes',
                        value: minutes.toString(),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              if (!_showExercises)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your activity',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      filtered.length.toString() + ' workouts',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              if (_showExercises)
                ...workoutExercisePresets.map(
                  (item) => _ExerciseCard(
                    item: item,
                    onAdd: () => _add(preset: item),
                  ),
                )
              else if (filtered.isEmpty)
                const AppEmptyState(
                  icon: Icons.fitness_center_outlined,
                  title: 'Ready to get moving?',
                  message:
                      'Add your first workout to start building your fitness history.',
                )
              else
                ...filtered.map((w) => _WorkoutCard(workout: w)),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _add,
                  style: FilledButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: const Color(0xFF080D0B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text(
                    'Add Workout',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _WorkoutStat extends StatelessWidget {
  const _WorkoutStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF141B17),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF27332B)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF25351D),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _lime, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});
  final Workout workout;
  Future<void> _delete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text('Delete "' + workout.name + '" permanently?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF5F665D),
            ),
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
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await WorkoutService.instance.deleteWorkout(workout.id);
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Workout deleted.')));
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete workout. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _workoutImage(workout.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141B17),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF27332B)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: image == null
                ? Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFF25351D),
                    child: Icon(
                      _workoutIcon(workout.category),
                      color: _lime,
                      size: 25,
                    ),
                  )
                : Image.asset(image, width: 52, height: 52, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  workout.category,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: _muted),
                    const SizedBox(width: 4),
                    Text(
                      workout.formattedDuration,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    if (workout.sets != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${workout.sets} sets',
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                    if (workout.reps != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${workout.reps} reps',
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(workout.date),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: _ink),
            onSelected: (v) {
              if (v == 'edit')
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditWorkoutScreen(workout: workout),
                  ),
                );
              if (v == 'delete') _delete(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit workout')),
              PopupMenuItem(value: 'delete', child: Text('Delete workout')),
            ],
          ),
        ],
      ),
    );
  }
}

String? _workoutImage(String name) {
  final value = name.toLowerCase();
  if (value.contains('push up') || value.contains('push-up'))
    return 'assets/images/workouts/push_up.jpg';
  if (value.contains('squat')) return 'assets/images/workouts/squat.jpg';
  if (value.contains('bench')) return 'assets/images/workouts/bench_press.jpg';
  if (value.contains('plank')) return 'assets/images/workouts/plank.jpg';
  if (value.contains('run') || value.contains('jog'))
    return 'assets/images/workouts/running.jpg';
  return null;
}

IconData _workoutIcon(String category) => switch (category) {
  'Cardio' => Icons.directions_run_rounded,
  'Flexibility' => Icons.self_improvement_rounded,
  'HIIT' => Icons.bolt_rounded,
  'Strength' => Icons.fitness_center_rounded,
  _ => Icons.sports_gymnastics_rounded,
};

class WorkoutExercisePreset {
  const WorkoutExercisePreset({
    required this.name,
    required this.category,
    required this.detail,
    required this.icon,
    required this.image,
    this.sets,
    this.reps,
    required this.duration,
    this.durationUnit = 'minutes',
  });
  final String name, category, detail, image, durationUnit;
  final IconData icon;
  final int? sets, reps;
  final int duration;
}

const workoutExercisePresets = [
  WorkoutExercisePreset(
    name: 'Push Up',
    category: 'Strength',
    detail: '3 sets Â· 15 reps',
    icon: Icons.fitness_center_rounded,
    image: 'assets/images/workouts/push_up.jpg',
    sets: 3,
    reps: 15,
    duration: 30,
  ),
  WorkoutExercisePreset(
    name: 'Squat',
    category: 'Strength',
    detail: '4 sets Â· 12 reps',
    icon: Icons.accessibility_new_rounded,
    image: 'assets/images/workouts/squat.jpg',
    sets: 4,
    reps: 12,
    duration: 30,
  ),
  WorkoutExercisePreset(
    name: 'Bench Press',
    category: 'Strength',
    detail: '4 sets Â· 10 reps',
    icon: Icons.fitness_center_rounded,
    image: 'assets/images/workouts/bench_press.jpg',
    sets: 4,
    reps: 10,
    duration: 30,
  ),
  WorkoutExercisePreset(
    name: 'Plank',
    category: 'Full Body',
    detail: '3 sets Â· 60 sec',
    icon: Icons.self_improvement_rounded,
    image: 'assets/images/workouts/plank.jpg',
    sets: 3,
    duration: 60,
    durationUnit: 'seconds',
  ),
  WorkoutExercisePreset(
    name: 'Running',
    category: 'Cardio',
    detail: '30 min',
    icon: Icons.directions_run_rounded,
    image: 'assets/images/workouts/running.jpg',
    duration: 30,
  ),
];

Widget _topTab(String label, bool selected, VoidCallback onTap) => Material(
  color: selected ? _lime : Colors.transparent,
  borderRadius: BorderRadius.circular(10),
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? const Color(0xFF080D0B) : _muted,
        ),
      ),
    ),
  ),
);

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.item, required this.onAdd});
  final WorkoutExercisePreset item;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF141B17),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF202B24)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                item.image,
                width: 58,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 58,
                  height: 48,
                  color: const Color(0xFF25351D),
                  child: Icon(item.icon, color: _lime, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.detail,
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(
                Icons.play_circle_outline_rounded,
                color: _lime,
                size: 24,
              ),
              tooltip: 'Log workout',
            ),
          ],
        ),
      ),
    ),
  );
}
