import 'package:fittrack/src/models/workout.dart';
import 'package:fittrack/src/screens/workout/workout_form.dart';
import 'package:fittrack/src/screens/workout/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preset in workoutExercisePresets) {
    testWidgets('${preset.name} preset is prefilled and editable', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WorkoutForm(
            initialName: preset.name,
            initialCategory: preset.category,
            initialSets: preset.sets,
            initialReps: preset.reps,
            initialDuration: preset.duration,
            initialDurationUnit: preset.durationUnit,
            submitLabel: 'Save workout',
            onSubmit: (_) async {},
          ),
        ),
      ));

      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields[0].controller!.text, preset.name);
      expect(fields[1].controller!.text, preset.duration.toString());
      expect(fields[2].controller!.text, preset.sets?.toString() ?? '');
      expect(fields[3].controller!.text, preset.reps?.toString() ?? '');
      expect(find.text(preset.category), findsOneWidget);
      expect(find.text(preset.durationUnit == 'seconds' ? 'Seconds' : 'Minutes'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '${preset.name} edited');
      expect(fields[0].controller!.text, '${preset.name} edited');
    });
  }

  test('Workout keeps old minute records compatible and stores optional set details', () {
    final workout = Workout(
      id: 'workout-1',
      name: 'Plank',
      category: 'Full Body',
      duration: 60,
      durationUnit: 'seconds',
      sets: 3,
      date: DateTime(2026, 1, 1),
    );

    expect(workout.durationInMinutes, 1);
    expect(workout.formattedDuration, '60 sec');
    expect(workout.toMap()['durationUnit'], 'seconds');
    expect(workout.toMap()['sets'], 3);

    final oldWorkout = Workout(
      id: 'old-workout',
      name: 'Run',
      category: 'Cardio',
      duration: 30,
      date: DateTime(2026, 1, 1),
    );
    expect(oldWorkout.durationUnit, 'minutes');
    expect(oldWorkout.durationInMinutes, 30);
    expect(oldWorkout.toMap()['durationUnit'], 'minutes');
  });
}
