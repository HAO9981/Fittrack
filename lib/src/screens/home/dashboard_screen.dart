import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/dashboard_stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Stream<List<Workout>> _todayWorkoutsStream;
  late final Stream<List<Workout>> _recentWorkoutsStream;
  late final Stream<List<Meal>> _todayMealsStream;
  late final Stream<List<Meal>> _recentMealsStream;

  @override
  void initState() {
    super.initState();
    // Create each Firestore stream once for this screen instead of creating
    // new query/listener objects every time the dashboard rebuilds.
    _todayWorkoutsStream = WorkoutService.instance.getTodayWorkouts();
    _recentWorkoutsStream = WorkoutService.instance.getRecentWorkouts();
    _todayMealsStream = NutritionService.instance.getTodayMeals();
    _recentMealsStream = NutritionService.instance.getRecentMeals();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('FitTrack')),
      body: StreamBuilder<List<Workout>>(
        stream: _todayWorkoutsStream,
        builder: (context, todayWorkoutSnapshot) => StreamBuilder<List<Workout>>(
          stream: _recentWorkoutsStream,
          builder: (context, recentWorkoutSnapshot) => StreamBuilder<List<Meal>>(
            stream: _todayMealsStream,
            builder: (context, todayMealSnapshot) => StreamBuilder<List<Meal>>(
              stream: _recentMealsStream,
              builder: (context, recentMealSnapshot) {
                final snapshots = [
                  todayWorkoutSnapshot,
                  recentWorkoutSnapshot,
                  todayMealSnapshot,
                  recentMealSnapshot,
                ];

                if (snapshots.any((snapshot) => snapshot.connectionState == ConnectionState.waiting)) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshots.any((snapshot) => snapshot.hasError)) {
                  return const AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Dashboard unavailable',
                    message: 'Your latest activity could not be loaded.',
                  );
                }

                return _DashboardContent(
                  userName: user?.displayName ?? 'User',
                  todayWorkouts: todayWorkoutSnapshot.data ?? [],
                  recentWorkouts: recentWorkoutSnapshot.data ?? [],
                  todayMeals: todayMealSnapshot.data ?? [],
                  recentMeals: recentMealSnapshot.data ?? [],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.userName,
    required this.todayWorkouts,
    required this.recentWorkouts,
    required this.todayMeals,
    required this.recentMeals,
  });

  final String userName;
  final List<Workout> todayWorkouts;
  final List<Workout> recentWorkouts;
  final List<Meal> todayMeals;
  final List<Meal> recentMeals;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final greeting = today.hour < 12
        ? 'Good morning'
        : today.hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final workoutMinutes = todayWorkouts.fold(0, (total, workout) => total + workout.duration);
    final weeklyMinutes = recentWorkouts.fold(0, (total, workout) => total + workout.duration);
    final calories = todayMeals.fold(0, (total, meal) => total + meal.calories);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('$greeting, $userName', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(MaterialLocalizations.of(context).formatFullDate(today), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        SizedBox(
          height: 150,
          child: Row(
            children: [
              Expanded(child: DashboardStatCard(icon: Icons.timer_outlined, label: 'Workout time', value: '$workoutMinutes min', color: Colors.deepPurple)),
              Expanded(child: DashboardStatCard(icon: Icons.local_fire_department_outlined, label: 'Calories', value: '$calories kcal', color: Colors.orange)),
              Expanded(child: DashboardStatCard(icon: Icons.check_circle_outline, label: 'Completed', value: '${todayWorkouts.length}', color: Colors.teal)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'Weekly overview', subtitle: '${recentWorkouts.length} workouts in the last 7 days'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: Text('$weeklyMinutes active minutes'),
            subtitle: const Text('Keep building a consistent routine.'),
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: 'Recent workouts'),
        if (recentWorkouts.isEmpty)
          const AppEmptyState(icon: Icons.fitness_center_outlined, title: 'No workouts yet', message: 'Your recent workouts will appear here.')
        else
          ...recentWorkouts.take(3).map((workout) => Card(child: ListTile(leading: const Icon(Icons.fitness_center), title: Text(workout.name), subtitle: Text('${workout.category} - ${workout.duration} min')))),
        const SizedBox(height: 20),
        _SectionTitle(title: 'Recent meals'),
        if (recentMeals.isEmpty)
          const AppEmptyState(icon: Icons.restaurant_outlined, title: 'No meals yet', message: 'Your recent meals will appear here.')
        else
          ...recentMeals.take(3).map((meal) => Card(child: ListTile(leading: const Icon(Icons.restaurant), title: Text(meal.foodName), subtitle: Text('${meal.category} - ${meal.calories} kcal')))),
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: () => FirebaseAuthService.instance.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}
