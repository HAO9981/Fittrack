import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/workout.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _surface = Color(0xFF141B17);
const _border = Color(0xFF27332B);

class WorkoutProgressScreen extends StatelessWidget {
  const WorkoutProgressScreen({super.key, required this.workouts});

  final List<Workout> workouts;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  int _minutes(Workout workout) =>
      workout.durationUnit == 'seconds'
          ? (workout.duration / 60).ceil()
          : workout.duration;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousStart = weekStart.subtract(const Duration(days: 7));
    final currentWeek = workouts.where((w) {
      final day = _day(w.date);
      return !day.isBefore(weekStart) && day.isBefore(weekStart.add(const Duration(days: 7)));
    }).toList();
    final previousWeek = workouts.where((w) {
      final day = _day(w.date);
      return !day.isBefore(previousStart) && day.isBefore(weekStart);
    }).toList();

    final weekMinutes = currentWeek.fold<int>(0, (sum, w) => sum + _minutes(w));
    final previousMinutes = previousWeek.fold<int>(0, (sum, w) => sum + _minutes(w));
    final weekReps = currentWeek.fold<int>(0, (sum, w) => sum + (w.reps ?? 0));
    final previousReps = previousWeek.fold<int>(0, (sum, w) => sum + (w.reps ?? 0));
    final aiSessions = currentWeek.where((w) => w.repsPerMinute != null).length;
    final activeDays = currentWeek.map((w) => _day(w.date)).toSet().length;

    final dailyCounts = List<int>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      return currentWeek.where((w) => _day(w.date) == date).length;
    });
    final maxCount = dailyCounts.fold<int>(1, (maxValue, value) => value > maxValue ? value : maxValue);

    final allTimeReps = workouts.fold<int>(0, (sum, w) => sum + (w.reps ?? 0));
    final allTimeMinutes = workouts.fold<int>(0, (sum, w) => sum + _minutes(w));
    final allTimeAiSessions = workouts.where((w) => w.repsPerMinute != null).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text('Workout Progress', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('THIS WEEK', style: TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _ProgressMetric(label: 'WORKOUTS', value: '${currentWeek.length}', icon: Icons.fitness_center_rounded)),
              const SizedBox(width: 9),
              Expanded(child: _ProgressMetric(label: 'ACTIVE DAYS', value: '$activeDays / 7', icon: Icons.calendar_today_rounded)),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: _ProgressMetric(label: 'TOTAL TIME', value: '${weekMinutes}m', icon: Icons.schedule_rounded)),
              const SizedBox(width: 9),
              Expanded(child: _ProgressMetric(label: 'TOTAL REPS', value: '$weekReps', icon: Icons.repeat_rounded)),
            ]),
            const SizedBox(height: 14),
            _WeeklyGoalProgress(workouts: currentWeek, weekMinutes: weekMinutes),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('WEEKLY ACTIVITY', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Number of saved workouts per day', style: TextStyle(color: _muted, fontSize: 11)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 126,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final count = dailyCounts[index];
                      final barHeight = count == 0 ? 5.0 : 12 + (count / maxCount) * 70;
                      final date = weekStart.add(Duration(days: index));
                      const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('$count', style: const TextStyle(color: _muted, fontSize: 10)),
                            const SizedBox(height: 6),
                            Container(
                              height: barHeight,
                              width: 18,
                              decoration: BoxDecoration(
                                color: count == 0 ? _border : _lime,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(labels[index], style: TextStyle(color: _day(date) == today ? _lime : _muted, fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('WEEK-OVER-WEEK', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 12),
                _ComparisonRow(label: 'Workout sessions', current: currentWeek.length, previous: previousWeek.length),
                const SizedBox(height: 12),
                _ComparisonRow(label: 'Training minutes', current: weekMinutes, previous: previousMinutes),
                const SizedBox(height: 12),
                _ComparisonRow(label: 'Recorded reps', current: weekReps, previous: previousReps),
                const SizedBox(height: 10),
                const Text('Compared with the previous Monday–Sunday period.', style: TextStyle(color: _muted, fontSize: 10)),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ALL-TIME TOTALS', style: TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 13),
                _TotalRow(label: 'Saved workout sessions', value: '${workouts.length}'),
                _TotalRow(label: 'Total training time', value: '${allTimeMinutes} min'),
                _TotalRow(label: 'Recorded repetitions', value: '$allTimeReps'),
                _TotalRow(label: 'AI-analyzed sessions', value: '$allTimeAiSessions'),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              '$aiSessions AI-analyzed session${aiSessions == 1 ? '' : 's'} this week. Only saved workouts are included in these statistics.',
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _lime, size: 17),
      const SizedBox(height: 10),
      Text(value, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    ]),
  );
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label, required this.current, required this.previous});
  final String label;
  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final difference = current - previous;
    final change = previous == 0
        ? (current == 0 ? '—' : '+$current')
        : '${difference >= 0 ? '+' : ''}$difference';
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
      Text('$previous', style: const TextStyle(color: _muted, fontSize: 12)),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward_rounded, color: _muted, size: 14)),
      Text('$current', style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(width: 9),
      Text(change, style: TextStyle(color: difference >= 0 ? _lime : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
      Text(value, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}


class _WeeklyGoalProgress extends StatelessWidget {
  const _WeeklyGoalProgress({required this.workouts, required this.weekMinutes});
  final List<Workout> workouts;
  final int weekMinutes;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final sessionGoal = (data?['workoutGoalSessionsPerWeek'] as num?)?.toInt() ?? 3;
        final minuteGoal = (data?['workoutGoalMinutesPerWeek'] as num?)?.toInt() ?? 150;
        final sessionProgress = (workouts.length / sessionGoal).clamp(0.0, 1.0);
        final minuteProgress = (weekMinutes / minuteGoal).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('WEEKLY GOALS', style: TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 13),
            _GoalProgressLine(label: 'Workout sessions', current: workouts.length, target: sessionGoal, progress: sessionProgress, unit: 'sessions'),
            const SizedBox(height: 16),
            _GoalProgressLine(label: 'Training time', current: weekMinutes, target: minuteGoal, progress: minuteProgress, unit: 'min'),
            if (snapshot.hasError)
              const Padding(padding: EdgeInsets.only(top: 8), child: Text('Unable to refresh saved goals.', style: TextStyle(color: Colors.orangeAccent, fontSize: 10))),
          ]),
        );
      },
    );
  }
}

class _GoalProgressLine extends StatelessWidget {
  const _GoalProgressLine({required this.label, required this.current, required this.target, required this.progress, required this.unit});
  final String label, unit;
  final int current, target;
  final double progress;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700))),
      Text('$current / $target $unit', style: const TextStyle(color: _muted, fontSize: 11)),
    ]),
    const SizedBox(height: 8),
    ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: _border, valueColor: const AlwaysStoppedAnimation<Color>(_lime))),
    const SizedBox(height: 4),
    Text('${(progress * 100).round()}% completed', style: const TextStyle(color: _muted, fontSize: 10)),
  ]);
}
