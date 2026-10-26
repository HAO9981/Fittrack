import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../services/workout_service.dart';
import 'workout_form.dart';

class AddWorkoutScreen extends StatelessWidget {
  const AddWorkoutScreen({
    super.key,
    this.initialName,
    this.initialCategory,
    this.initialSets,
    this.initialReps,
    this.initialDuration,
    this.initialDurationUnit = 'minutes',
  });

  final String? initialName;
  final String? initialCategory;
  final int? initialSets;
  final int? initialReps;
  final int? initialDuration;
  final String initialDurationUnit;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add Workout')),
        body: SafeArea(
          child: WorkoutForm(
            initialName: initialName,
            initialCategory: initialCategory,
            initialSets: initialSets,
            initialReps: initialReps,
            initialDuration: initialDuration,
            initialDurationUnit: initialDurationUnit,
            submitLabel: 'Save workout',
            onSubmit: (Workout workout) => WorkoutService.instance.addWorkout(workout),
          ),
        ),
      );
}
