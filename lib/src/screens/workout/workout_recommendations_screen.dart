import 'package:flutter/material.dart';
import '../../models/workout.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _surface = Color(0xFF141B17);

class WorkoutRecommendationsScreen extends StatelessWidget {
  const WorkoutRecommendationsScreen({super.key, required this.workouts});

  final List<Workout> workouts;

  @override
  Widget build(BuildContext context) {
    final sorted = [...workouts]..sort((a, b) => b.date.compareTo(a.date));
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final thisWeek = sorted.where((w) => !w.date.isBefore(weekStart)).toList();
    final recent = sorted.where((w) => !w.date.isBefore(now.subtract(const Duration(days: 14)))).toList();
    final categoryCounts = <String, int>{};
    for (final workout in recent) {
      categoryCounts[workout.category] = (categoryCounts[workout.category] ?? 0) + 1;
    }
    final dominant = categoryCounts.entries.isEmpty
        ? null
        : categoryCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final daysSinceLast = sorted.isEmpty ? null : now.difference(sorted.first.date).inDays;
    final pushUps = sorted.where((w) =>
      w.name.toLowerCase().contains('push up') ||
      w.name.toLowerCase().contains('push-up')).toList();
    final latestPushUp = pushUps.isEmpty ? null : pushUps.first;
    final previousPushUp = pushUps.length < 2 ? null : pushUps[1];

    final suggestions = <_Recommendation>[];
    if (sorted.isEmpty) {
      suggestions.add(const _Recommendation(
        icon: Icons.flag_rounded,
        title: 'Start with a simple session',
        body: 'Log your first workout to build a training history. A short, comfortable session is a good starting point.',
        tag: 'GET STARTED',
      ));
    } else {
      if (daysSinceLast! >= 4) {
        suggestions.add(_Recommendation(
          icon: Icons.directions_walk_rounded,
          title: 'Ease back into your routine',
          body: 'Your latest saved workout was $daysSinceLast days ago. Consider a light session or a walk, then build up gradually.',
          tag: 'CONSISTENCY',
        ));
      } else if (thisWeek.length < 2) {
        suggestions.add(_Recommendation(
          icon: Icons.calendar_month_rounded,
          title: 'Plan another active day',
          body: 'You have logged ${thisWeek.length} workout(s) this week. If you feel recovered, consider scheduling another manageable session.',
          tag: 'WEEKLY ROUTINE',
        ));
      } else {
        suggestions.add(const _Recommendation(
          icon: Icons.check_circle_outline_rounded,
          title: 'Keep your routine steady',
          body: 'You have logged multiple workouts this week. Keep a sustainable pace and allow time for recovery between demanding sessions.',
          tag: 'CONSISTENCY',
        ));
      }

      if (dominant != null && recent.length >= 3) {
        suggestions.add(_Recommendation(
          icon: Icons.balance_rounded,
          title: 'Review your workout variety',
          body: '${dominant.key} is your most frequent category in the last 14 days (${dominant.value} sessions). Consider including other activities that match your goals.',
          tag: 'TRAINING BALANCE',
        ));
      } else {
        suggestions.add(const _Recommendation(
          icon: Icons.category_rounded,
          title: 'Build a varied routine',
          body: 'Your recent history is still taking shape. Try logging different workout categories so you can review your training balance over time.',
          tag: 'TRAINING BALANCE',
        ));
      }

      if (latestPushUp != null && previousPushUp != null &&
          latestPushUp.reps != null && previousPushUp.reps != null) {
        final difference = latestPushUp.reps! - previousPushUp.reps!;
        final message = difference > 0
            ? 'Your latest saved push-up session has $difference more rep(s) than the previous one.'
            : difference < 0
                ? 'Your latest saved push-up session has ${difference.abs()} fewer rep(s) than the previous one. Compare the sessions under similar conditions.'
                : 'Your latest two saved push-up sessions have the same rep count.';
        suggestions.add(_Recommendation(
          icon: Icons.fitness_center_rounded,
          title: 'Push-up history insight',
          body: '$message Use comfortable form and avoid chasing numbers at the expense of technique.',
          tag: 'BASED ON YOUR LOGS',
        ));
      } else {
        suggestions.add(const _Recommendation(
          icon: Icons.insights_rounded,
          title: 'Collect more performance data',
          body: 'Save more sessions, including AI push-up analyses, to make useful comparisons between your recorded results.',
          tag: 'PROGRESS INSIGHT',
        ));
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _ink,
        title: const Text('Workout Recommendations', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF526B3D)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: _lime, size: 25),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your training snapshot', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
                    SizedBox(height: 5),
                    Text('Suggestions are generated from your saved workout history. They are general fitness ideas, not medical advice or a personalised training prescription.', style: TextStyle(color: _muted, height: 1.45, fontSize: 11)),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Metric(value: sorted.length.toString(), label: 'Total sessions')),
            const SizedBox(width: 10),
            Expanded(child: _Metric(value: thisWeek.length.toString(), label: 'This week')),
            const SizedBox(width: 10),
            Expanded(child: _Metric(value: recent.length.toString(), label: 'Last 14 days')),
          ]),
          const SizedBox(height: 22),
          const Text('Suggested next steps', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 11),
          for (final item in suggestions) _RecommendationCard(item: item),
          if (sorted.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.history_rounded, color: _lime),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  daysSinceLast == 0 ? 'Your latest saved workout is today.' : 'Your latest saved workout was $daysSinceLast day(s) ago.',
                  style: const TextStyle(color: _muted, fontSize: 12),
                )),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Recommendation {
  const _Recommendation({required this.icon, required this.title, required this.body, required this.tag});
  final IconData icon;
  final String title;
  final String body;
  final String tag;
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item});
  final _Recommendation item;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFF27332B))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: _lime)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.tag, style: const TextStyle(color: _lime, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(item.title, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(item.body, style: const TextStyle(color: _muted, fontSize: 12, height: 1.45)),
      ])),
    ]),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
    decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF27332B))),
    child: Column(children: [
      Text(value, style: const TextStyle(color: _lime, fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 10)),
    ]),
  );
}
