import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../models/workout.dart';
import '../../models/meal.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_empty_state.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final Stream<List<Workout>> _workoutsStream;
  late final Stream<List<Meal>> _mealsStream;
  late final Stream<UserProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _workoutsStream = WorkoutService.instance.getRecentWorkouts(
      lookback: const Duration(days: 30),
      limit: 100,
    );
    _mealsStream = NutritionService.instance.getRecentMeals(
      lookback: const Duration(days: 30),
      limit: 100,
    );

    final user = FirebaseAuthService.instance.currentUser;
    _profileStream = user == null
        ? Stream<UserProfile?>.value(null)
        : FirestoreService.instance.userProfileStream(user.uid);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: StreamBuilder<List<Workout>>(
          stream: _workoutsStream,
          builder: (context, workoutSnapshot) => StreamBuilder<List<Meal>>(
            stream: _mealsStream,
            builder: (context, mealSnapshot) => StreamBuilder<UserProfile?>(
              stream: _profileStream,
              builder: (context, profileSnapshot) {
                if ([workoutSnapshot, mealSnapshot, profileSnapshot].any(
                  (snapshot) => snapshot.connectionState == ConnectionState.waiting,
                )) {
                  return const Center(child: CircularProgressIndicator());
                }

                if ([workoutSnapshot, mealSnapshot, profileSnapshot].any(
                  (snapshot) => snapshot.hasError,
                )) {
                  return const AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Progress unavailable',
                    message: 'Your progress data could not be loaded.',
                  );
                }

                return _ProgressContent(
                  workouts: workoutSnapshot.data ?? [],
                  meals: mealSnapshot.data ?? [],
                  profile: profileSnapshot.data,
                );
              },
            ),
          ),
        ),
      );
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.workouts,
    required this.meals,
    required this.profile,
  });

  final List<Workout> workouts;
  final List<Meal> meals;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final weeklyWorkouts = workouts.where((workout) {
      final date = DateTime(workout.date.year, workout.date.month, workout.date.day);
      return !date.isBefore(weekStart) && !date.isAfter(today);
    }).toList();
    final weeklyMeals = meals.where((meal) {
      final date = DateTime(meal.date.year, meal.date.month, meal.date.day);
      return !date.isBefore(weekStart) && !date.isAfter(today);
    }).toList();

    final weeklyMinutes = weeklyWorkouts.fold(0, (total, workout) => total + workout.duration);
    final weeklyCalories = weeklyMeals.fold(0, (total, meal) => total + meal.calories);
    final averageDailyCalories = weeklyMeals.isEmpty ? 0 : (weeklyCalories / 7).round();
    final workoutGoal = 3;
    final workoutProgress = (weeklyWorkouts.length / workoutGoal).clamp(0.0, 1.0);
    final bmi = _calculateBmi(profile?.weightKg, profile?.heightCm);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Your progress', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('A summary of your recent activity.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _MetricCard(icon: Icons.fitness_center, value: '${weeklyWorkouts.length}', label: 'Workouts')),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(icon: Icons.timer_outlined, value: '$weeklyMinutes min', label: 'Active time')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(icon: Icons.local_fire_department_outlined, value: '$weeklyCalories kcal', label: '7-day calories')),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(icon: Icons.monitor_weight_outlined, value: profile?.weightKg == null ? '--' : '${_formatNumber(profile!.weightKg!)} kg', label: 'Current weight')),
          ],
        ),
        const SizedBox(height: 24),
        Text('Weekly workout goal', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${weeklyWorkouts.length} of $workoutGoal workouts'),
                    Text('${(workoutProgress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: workoutProgress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                const SizedBox(height: 8),
                const Text('Aim for at least 3 workouts each week.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Nutrition overview', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restaurant_outlined),
            title: Text('$averageDailyCalories kcal/day'),
            subtitle: Text('${weeklyMeals.length} meals recorded in the last 7 days'),
          ),
        ),
        const SizedBox(height: 24),
        Text('Body metrics', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.monitor_weight_outlined),
                title: const Text('Current weight'),
                trailing: Text(profile?.weightKg == null ? 'Not set' : '${_formatNumber(profile!.weightKg!)} kg'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.height_outlined),
                title: const Text('Height'),
                trailing: Text(profile?.heightCm == null ? 'Not set' : '${_formatNumber(profile!.heightCm!)} cm'),
              ),
              if (bmi != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('BMI'),
                  trailing: Text(bmi.toStringAsFixed(1)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Fitness goal', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(profile?.fitnessGoal ?? 'Not set'),
            subtitle: const Text('Update your goal in Profile to keep your progress relevant.'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static double? _calculateBmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || weightKg <= 0 || heightCm <= 0) return null;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  static String _formatNumber(double value) => value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}
