import 'package:flutter/material.dart';

import '../../models/workout.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _surface = Color(0xFF141B17);
const _border = Color(0xFF27332B);

class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workout});

  final Workout workout;

  String get _dateLabel {
    final date = workout.date;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String get _summary {
    final reps = workout.reps;
    if (reps == null) {
      return 'This workout is saved in your training history.';
    }
    if (reps == 0) {
      return 'No complete repetitions were recorded for this session.';
    }
    final rate = workout.repsPerMinute;
    if (rate == null) return 'You completed $reps repetitions in this session.';
    if (rate >= 20) return 'A fast pace was recorded. Keep your movement controlled and prioritize good form.';
    if (rate >= 10) return 'A steady pace was recorded. Aim for smooth and consistent repetitions.';
    return 'A measured pace was recorded. Focus on controlled movement and a comfortable rhythm.';
  }

  @override
  Widget build(BuildContext context) {
    final isAi = workout.name.toLowerCase().contains('ai push-up');
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text('Workout Details', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fitness_center_rounded, color: _lime, size: 22),
                      const SizedBox(width: 8),
                      Text(workout.category.toUpperCase(), style: const TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                      const Spacer(),
                      if (isAi)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(color: _lime.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: const Text('AI ANALYSIS', style: TextStyle(color: _lime, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(workout.name, style: const TextStyle(color: _ink, fontSize: 23, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(_dateLabel, style: const TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('SESSION OVERVIEW', style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                _DetailMetric(label: 'DURATION', value: workout.formattedDuration, icon: Icons.schedule_rounded),
                _DetailMetric(label: 'REPETITIONS', value: workout.reps?.toString() ?? '--', icon: Icons.repeat_rounded),
                _DetailMetric(label: 'SETS', value: workout.sets?.toString() ?? '--', icon: Icons.view_agenda_outlined),
                _DetailMetric(label: 'PACE', value: workout.repsPerMinute == null ? '--' : '${workout.repsPerMinute!.toStringAsFixed(1)}/min', icon: Icons.speed_rounded),
              ],
            ),
            if (workout.averageRepIntervalSeconds != null) ...[
              const SizedBox(height: 10),
              _DetailMetric(
                label: 'AVERAGE TIME BETWEEN REPS',
                value: '${workout.averageRepIntervalSeconds!.toStringAsFixed(1)} sec',
                icon: Icons.timer_outlined,
                wide: true,
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SESSION SUMMARY', style: TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 9),
                  Text(_summary, style: const TextStyle(color: _ink, fontSize: 13, height: 1.5)),
                  if (isAi) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'AI metrics are estimates derived from the detected repetitions and recorded video duration. They are not a medical or form assessment.',
                      style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.wide = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
    width: wide ? double.infinity : null,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(children: [
          Icon(icon, color: _lime, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6))),
        ]),
        const SizedBox(height: 9),
        Text(value, style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
