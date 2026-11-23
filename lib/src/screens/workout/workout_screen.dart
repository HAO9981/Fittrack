import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../services/workout_category_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_workout_screen.dart';
import 'edit_workout_screen.dart';
import 'workout_categories_screen.dart';
import 'push_up_video_analysis_screen.dart';
import 'push_up_recording_screen.dart';
import 'push_up_live_counter_screen.dart';
import 'workout_detail_screen.dart';
import 'workout_progress_screen.dart';
import 'workout_recommendations_screen.dart';
import 'workout_goals_screen.dart';
import 'workout_calendar_screen.dart';
import '../ai/ai_assistant_screen.dart';
import '../../navigation/app_navigation.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, this.initialShowExercises = false});
  final bool initialShowExercises;
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String _filter = 'All';
  late bool _showExercises;
  bool _showAllWorkouts = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final Stream<List<Workout>> _workoutsStream;
  late final Stream<WorkoutCategorySettings> _categorySettingsStream;

  @override
  void initState() {
    super.initState();
    _showExercises = widget.initialShowExercises;
    _workoutsStream = WorkoutService.instance.getWorkouts();
    _categorySettingsStream = WorkoutCategoryService.instance.watch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openAiTracking(String exerciseName) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF141B17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF465248),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'AI $exerciseName Tracking',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how you want to count your ${exerciseName.toLowerCase()} reps.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: const Color(0xFF26391D),
                leading: const Icon(Icons.camera_alt_rounded, color: _lime),
                title: const Text(
                  'Record with Camera',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Count repetitions in real time',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                onTap: () => Navigator.pop(sheetContext, 'record'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: const Color(0xFF202B24),
                leading: const Icon(Icons.video_library_rounded, color: _lime),
                title: const Text(
                  'Import Video',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Analyze an existing workout video',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                onTap: () => Navigator.pop(sheetContext, 'video'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || method == null) return;
    final screen = method == 'record'
        ? PushUpLiveCounterScreen(exerciseName: exerciseName)
        : PushUpVideoAnalysisScreen(exerciseName: exerciseName);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _lime));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error is StateError
                      ? 'Please sign in to view your workouts.'
                      : 'Unable to load workouts. Please try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _ink),
                ),
              ),
            );
          }

          final all = snapshot.data ?? <Workout>[];
          final today = DateTime.now();
          final date = DateTime(today.year, today.month, today.day);
          final weekStart = date.subtract(Duration(days: date.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final thisWeek = all.where((w) =>
              !w.date.isBefore(weekStart) && w.date.isBefore(weekEnd)).toList();
          final weekMinutes = thisWeek.fold<int>(
              0, (sum, workout) => sum + workout.durationInMinutes);
          final filtered = all.where((w) {
            final categoryMatch = _filter == 'All' ||
                w.category.toLowerCase() == _filter.toLowerCase();
            final query = _searchQuery.trim().toLowerCase();
            final searchMatch = query.isEmpty ||
                w.name.toLowerCase().contains(query) ||
                w.category.toLowerCase().contains(query);
            return categoryMatch && searchMatch;
          }).toList();
          final user = FirebaseAuthService.instance.currentUser;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            children: [
              Row(
                children: [
                  IconButton(tooltip: 'Open navigation menu', onPressed: AppNavigation.openDrawer, icon: const Icon(Icons.menu_rounded, color: _ink, size: 25)),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Workout', style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800, color: _ink)),
                        SizedBox(height: 3),
                        Text('Track your workouts and stay consistent',
                            style: TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                  Material(
                    color: _lime,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _add,
                      borderRadius: BorderRadius.circular(16),
                      child: const SizedBox(width: 48, height: 48,
                          child: Icon(Icons.add_rounded, color: _bg, size: 28)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weekly totals are calculated from saved records; the target is read from the user's profile document.
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: user == null ? null : FirebaseFirestore.instance
                    .collection('users').doc(user.uid).snapshots(),
                builder: (context, goalSnapshot) {
                  final data = goalSnapshot.data?.data();
                  final target = (data?['workoutGoalSessionsPerWeek'] as num?)?.toInt() ?? 3;
                  final safeTarget = target < 1 ? 1 : target;
                  final progress = (thisWeek.length / safeTarget).clamp(0.0, 1.0);
                  final weekLastDay = weekEnd.subtract(const Duration(days: 1));
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141B17),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF304332)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: _lime, size: 20),
                            const SizedBox(width: 9),
                            const Expanded(child: Text('This Week', style: TextStyle(
                              color: _ink, fontSize: 16, fontWeight: FontWeight.w800))),
                            Text(
                              '${_monthShort(weekStart.month)} ${weekStart.day} – ${_monthShort(weekLastDay.month)} ${weekLastDay.day}',
                              style: const TextStyle(color: _muted, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: _WeeklyMetric(
                              icon: Icons.directions_run_rounded,
                              value: thisWeek.length.toString(), label: 'Workouts')),
                            Container(width: 1, height: 48, color: const Color(0xFF304035)),
                            Expanded(child: _WeeklyMetric(
                              icon: Icons.schedule_rounded,
                              value: weekMinutes.toString(), label: 'Minutes')),
                            Container(width: 1, height: 48, color: const Color(0xFF304035)),
                            Expanded(child: _WeeklyMetric(
                              icon: Icons.track_changes_rounded,
                              value: '${thisWeek.length}/${safeTarget}', label: 'Goal')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progress, minHeight: 8,
                            backgroundColor: const Color(0xFF354039),
                            valueColor: const AlwaysStoppedAnimation<Color>(_lime),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18231A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF304332)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ready to train?', style: TextStyle(
                      color: _ink, fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Choose an exercise and record your training session.',
                        style: TextStyle(color: _muted, fontSize: 12)),
                    const SizedBox(height: 13),
                    SizedBox(
                      width: double.infinity, height: 46,
                      child: FilledButton.icon(
                        onPressed: _add,
                        style: FilledButton.styleFrom(
                          backgroundColor: _lime, foregroundColor: _bg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Workout',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Row(children: [
                Expanded(child: _QuickAction(
                  icon: Icons.bar_chart_rounded, label: 'Progress',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WorkoutProgressScreen(workouts: all))))),
                const SizedBox(width: 9),
                Expanded(child: _QuickAction(
                  icon: Icons.auto_awesome_rounded, label: 'Recommendations',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WorkoutRecommendationsScreen(workouts: all))))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _QuickAction(
                  icon: Icons.forum_rounded, label: 'FitTrack AI',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AiAssistantScreen())))),
                const SizedBox(width: 9),
                Expanded(child: _QuickAction(
                  icon: Icons.flag_rounded, label: 'Goals',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const WorkoutGoalsScreen())))),
              ]),
              const SizedBox(height: 8),
              _QuickAction(
                icon: Icons.calendar_month_rounded, label: 'Calendar',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WorkoutCalendarScreen(workouts: all)))),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B17),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: const Color(0xFF304332)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.center_focus_strong_rounded, color: _lime, size: 25),
                      const SizedBox(width: 10),
                      const Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Workout Analysis', style: TextStyle(
                            color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                          SizedBox(height: 3),
                          Text('Analyze your push-ups using a video or camera.',
                              style: TextStyle(color: _muted, fontSize: 11)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 13),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PushUpVideoAnalysisScreen())),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _lime, side: const BorderSide(color: _lime),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11)),
                        icon: const Icon(Icons.video_library_rounded, size: 17),
                        label: const Text('Upload Video', style: TextStyle(fontSize: 11)),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PushUpRecordingScreen())),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _lime, side: const BorderSide(color: _lime),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11)),
                        icon: const Icon(Icons.videocam_rounded, size: 17),
                        label: const Text('Record Video', style: TextStyle(fontSize: 11)),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PushUpLiveCounterScreen())),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _lime,
                          side: const BorderSide(color: Color(0xFF27332B)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.sensors_rounded, size: 17),
                        label: const Text('Live Rep Counter', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: _topTab('My Workouts', !_showExercises,
                      () => setState(() => _showExercises = false))),
                  Expanded(child: _topTab('Exercises', _showExercises,
                      () => setState(() => _showExercises = true))),
                ]),
              ),
              const SizedBox(height: 14),

              if (_showExercises) ...[
                ...workoutExercisePresets.map((item) => _ExerciseCard(
                  item: item,
                  onAdd: () => _add(preset: item),
                  onAiTrack: const {'Push Up', 'Squat', 'Sit-up'}.contains(item.name)
                      ? () => _openAiTracking(item.name)
                      : null,
                )),
              ] else ...[
                Row(children: [
                  const Expanded(child: Text('Recent Workouts', style: TextStyle(
                    color: _ink, fontSize: 18, fontWeight: FontWeight.w800))),
                  Text('${filtered.length} workouts',
                      style: const TextStyle(color: _lime, fontSize: 11)),
                ]),
                const SizedBox(height: 9),
                TextField(
                  controller: _searchController, focusNode: _searchFocusNode,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: _ink, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search workouts...', prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _searchFocusNode.requestFocus();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                    filled: true, fillColor: const Color(0xFF141B17),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF27332B))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF27332B))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _lime)),
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<WorkoutCategorySettings>(
                  stream: _categorySettingsStream,
                  builder: (context, categoriesSnapshot) {
                    final settings = categoriesSnapshot.data ?? const WorkoutCategorySettings();
                    final available = <String>{
                      ...WorkoutCategoryService.systemCategories,
                      ...settings.custom,
                      ...all.map((w) => w.category),
                    };
                    final filters = ['All', ...available.where(
                      (category) => !settings.hidden.contains(category))];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(child: Text('Categories', style: TextStyle(
                            color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => WorkoutCategoriesScreen(
                                legacyCategories: all.map((w) => w.category).toSet().toList()))),
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('Edit Categories'),
                            style: TextButton.styleFrom(
                              foregroundColor: _lime, visualDensity: VisualDensity.compact),
                          ),
                        ]),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: filters.map((filter) {
                            final selected = _filter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter), selected: selected,
                                onSelected: (_) => setState(() => _filter = filter),
                                backgroundColor: const Color(0xFF27332B),
                                selectedColor: _lime, side: BorderSide.none,
                                showCheckmark: false, shape: const StadiumBorder(),
                                labelStyle: TextStyle(
                                  fontSize: 11, color: selected ? _bg : _ink,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                              ),
                            );
                          }).toList()),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  const AppEmptyState(
                    icon: Icons.fitness_center_outlined,
                    title: 'Ready to get moving?',
                    message: 'Add your first workout to start building your fitness history.',
                  )
                else
                  ...( _showAllWorkouts ? filtered : filtered.take(3))
                      .map((w) => _WorkoutCard(workout: w)),
                if (filtered.length > 3)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => setState(
                        () => _showAllWorkouts = !_showAllWorkouts,
                      ),
                      child: Text(
                        _showAllWorkouts ? 'Show Less' : 'View All Workouts',
                        style: const TextStyle(color: _lime),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _add,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _lime, side: const BorderSide(color: _lime),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Workout'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );

  static String _monthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _WeeklyMetric extends StatelessWidget {
  const _WeeklyMetric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: _lime, size: 21),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(
        color: _ink, fontSize: 21, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF141B17),
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF27332B)),
        ),
        child: Row(children: [
          Icon(icon, color: _lime, size: 21),
          const SizedBox(width: 9),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700))),
          const Icon(Icons.chevron_right_rounded, color: _lime, size: 17),
        ]),
      ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkoutDetailScreen(workout: workout),
        ),
      ),
      child: Container(
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
                    if (workout.repsPerMinute != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${workout.repsPerMinute!.toStringAsFixed(1)} reps/min',
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
    name: 'Sit-up',
    category: 'Strength',
    detail: '3 sets · 15 reps',
    icon: Icons.accessibility_new_rounded,
    image: '',
    sets: 3,
    reps: 15,
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
  const _ExerciseCard({
    required this.item,
    required this.onAdd,
    this.onAiTrack,
  });
  final WorkoutExercisePreset item;
  final VoidCallback onAdd;
  final VoidCallback? onAiTrack;
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
            if (onAiTrack != null) ...[
              Material(
                color: _lime,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: onAiTrack,
                  borderRadius: BorderRadius.circular(30),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: _bg, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'AI',
                          style: TextStyle(
                            color: _bg,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
            ],
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
