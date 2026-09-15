import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_workout_screen.dart';
import 'edit_workout_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Workouts')),
        body: StreamBuilder<List<Workout>>(
          stream: WorkoutService.instance.getWorkouts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _WorkoutMessage(
                icon: Icons.error_outline,
                message: snapshot.error is StateError
                    ? 'Please sign in to view your workouts.'
                    : 'Unable to load workouts. Please try again.',
              );
            }

            final workouts = snapshot.data ?? [];
            if (workouts.isEmpty) {
              return const AppEmptyState(
                icon: Icons.fitness_center_outlined,
                title: 'Ready to get moving?',
                message: 'Add your first workout to start building your fitness history.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: workouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _WorkoutCard(workout: workouts[index]),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (FirebaseAuthService.instance.currentUser == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to add a workout.')));
              return;
            }
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddWorkoutScreen()));
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Workout'),
        ),
      );
}

class _WorkoutMessage extends StatelessWidget {
  const _WorkoutMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final Workout workout;

  Future<void> _deleteWorkout(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text('Delete "${workout.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;

    try {
      await WorkoutService.instance.deleteWorkout(workout.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete workout. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(_categoryIcon(workout.category), color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          title: Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${workout.category} - ${workout.duration} min\n${MaterialLocalizations.of(context).formatMediumDate(workout.date)}',
            ),
          ),
          isThreeLine: true,
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit workout',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EditWorkoutScreen(workout: workout)),
                ),
              ),
              IconButton(
                tooltip: 'Delete workout',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteWorkout(context),
              ),
            ],
          ),
        ),
      );
}

IconData _categoryIcon(String category) => switch (category) {
      'Cardio' => Icons.directions_run,
      'Flexibility' => Icons.self_improvement,
      'HIIT' => Icons.bolt,
      'Strength' => Icons.fitness_center,
      _ => Icons.sports_gymnastics,
    };
