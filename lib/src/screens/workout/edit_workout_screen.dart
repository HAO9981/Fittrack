import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../services/workout_service.dart';
import 'workout_form.dart';

class EditWorkoutScreen extends StatelessWidget {
  const EditWorkoutScreen({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit Workout')),
        body: SafeArea(
          child: WorkoutForm(
            workout: workout,
            submitLabel: 'Update workout',
            onSubmit: (updatedWorkout) => WorkoutService.instance.updateWorkout(updatedWorkout),
          ),
        ),
      );
}
