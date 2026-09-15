import 'package:flutter/material.dart';

import '../../models/workout.dart';
import '../../services/workout_service.dart';
import 'workout_form.dart';

class AddWorkoutScreen extends StatelessWidget {
  const AddWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add Workout')),
        body: SafeArea(
          child: WorkoutForm(
            submitLabel: 'Save workout',
            onSubmit: (Workout workout) => WorkoutService.instance.addWorkout(workout),
          ),
        ),
      );
}
