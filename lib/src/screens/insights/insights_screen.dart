import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../services/nutrition_service.dart';
import '../../services/workout_service.dart';

const _lime = Color(0xFF84E221);
const _ink = Color(0xFF232824);
const _muted = Color(0xFF858C83);
const _bg = Color(0xFFF6F7F4);

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('Your Insights', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: const TabBar(
          labelColor: _ink,
          unselectedLabelColor: _muted,
          indicatorColor: _lime,
          tabs: [Tab(text: 'History'), Tab(text: 'Progress'), Tab(text: 'For You')],
        ),
      ),
      body: StreamBuilder<List<Workout>>(
        stream: WorkoutService.instance.getWorkouts(),
        builder: (context, workoutSnapshot) => StreamBuilder<List<Meal>>(
          stream: NutritionService.instance.getMeals(),
          builder: (context, mealSnapshot) {
            if (workoutSnapshot.connectionState == ConnectionState.waiting || mealSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _lime));
            }
            if (workoutSnapshot.hasError || mealSnapshot.hasError) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Insights are unavailable right now. Please check your connection and try again.', textAlign: TextAlign.center)));
            }
            final workouts = workoutSnapshot.data ?? <Workout>[];
            final meals = mealSnapshot.data ?? <Meal>[];
            return TabBarView(children: [
              _HistoryTab(workouts: workouts, meals: meals),
              _ProgressTab(workouts: workouts, meals: meals),
              _RecommendationsTab(workouts: workouts, meals: meals),
            ]);
          },
        ),
      ),
    ),
  );
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.workouts, required this.meals});
  final List<Workout> workouts;
  final List<Meal> meals;

  @override Widget build(BuildContext context) {
    final entries = <_HistoryEntry>[
      ...workouts.map((w) => _HistoryEntry(date: w.date, title: w.name, subtitle: w.category + ' · ' + w.duration.toString() + ' min', icon: Icons.fitness_center_rounded)),
      ...meals.map((m) => _HistoryEntry(date: m.date, title: m.foodName, subtitle: m.category + ' · ' + m.calories.toString() + ' kcal', icon: Icons.restaurant_rounded)),
    ]..sort((a, b) => b.date.compareTo(a.date));
    if (entries.isEmpty) return const _InsightEmpty(icon: Icons.history_rounded, title: 'Your history starts here', message: 'Workouts and meals you record will show up in this timeline.');
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Recent activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 5),
      const Text('A combined timeline of your recorded workouts and meals.', style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 16),
      ...entries.take(100).map((entry) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF0F6E9), borderRadius: BorderRadius.circular(14)), child: Icon(entry.icon, color: _ink)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 4),
            Text(entry.subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 3),
            Text(MaterialLocalizations.of(context).formatMediumDate(entry.date), style: const TextStyle(fontSize: 11, color: _muted)),
          ])),
        ]),
      )),
    ]);
  }
}

class _HistoryEntry {
  const _HistoryEntry({required this.date, required this.title, required this.subtitle, required this.icon});
  final DateTime date;
  final String title, subtitle;
  final IconData icon;
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.workouts, required this.meals});
  final List<Workout> workouts;
  final List<Meal> meals;

  @override Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final minutes = List<int>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return workouts.where((w) => DateUtils.isSameDay(w.date, day)).fold<int>(0, (sum, w) => sum + w.duration);
    });
    final maxMinutes = minutes.fold<int>(0, (max, value) => value > max ? value : max);
    final weekMeals = meals.where((m) => !DateUtils.dateOnly(m.date).isBefore(today.subtract(const Duration(days: 6)))).toList();
    final weekWorkouts = workouts.where((w) => !DateUtils.dateOnly(w.date).isBefore(today.subtract(const Duration(days: 6)))).toList();
    final totalMinutes = weekWorkouts.fold<int>(0, (sum, w) => sum + w.duration);
    final totalCalories = weekMeals.fold<int>(0, (sum, m) => sum + m.calories);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Your week at a glance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 5),
      const Text('Based on the workouts and meals you have logged.', style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _ProgressStat(title: 'Workout time', value: totalMinutes.toString(), unit: 'minutes', icon: Icons.schedule_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _ProgressStat(title: 'Workouts', value: weekWorkouts.length.toString(), unit: 'sessions', icon: Icons.fitness_center_rounded)),
      ]),
      const SizedBox(height: 10),
      _ProgressStat(title: 'Food logged', value: totalCalories.toString(), unit: 'kcal across logged meals', icon: Icons.restaurant_rounded),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily workout minutes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 20),
        SizedBox(height: 125, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) {
          final height = maxMinutes == 0 ? 8.0 : (minutes[i] / maxMinutes * 84).clamp(8.0, 84.0).toDouble();
          final day = today.subtract(Duration(days: 6 - i));
          final active = DateUtils.isSameDay(day, today);
          return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(minutes[i].toString(), style: const TextStyle(fontSize: 9, color: _muted)),
            const SizedBox(height: 5),
            Container(height: height, width: 15, decoration: BoxDecoration(color: minutes[i] > 0 ? _lime : const Color(0xFFE7EAE4), borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 7),
            Text(labels[day.weekday - 1], style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w400, color: active ? _ink : _muted)),
          ]));
        }))),
      ])),
      const SizedBox(height: 12),
      const Text('Keep logging consistently to build a more useful progress picture.', style: TextStyle(fontSize: 12, color: _muted, height: 1.5)),
    ]);
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.title, required this.value, required this.unit, required this.icon});
  final String title, value, unit;
  final IconData icon;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19)), child: Row(children: [
    Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFF0F6E9), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: _ink)),
    const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 11, color: _muted)),
      const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
      Text(unit, style: const TextStyle(fontSize: 10, color: _muted)),
    ])),
  ]));
}

class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab({required this.workouts, required this.meals});
  final List<Workout> workouts;
  final List<Meal> meals;

  @override Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final weekStart = today.subtract(const Duration(days: 6));
    final recentWorkouts = workouts.where((w) => !DateUtils.dateOnly(w.date).isBefore(weekStart)).toList();
    final todayMeals = meals.where((m) => DateUtils.isSameDay(m.date, today)).toList();
    final todayWorkouts = workouts.where((w) => DateUtils.isSameDay(w.date, today)).toList();
    final cards = <_RecommendationData>[];
    if (recentWorkouts.length < 3) {
      cards.add(const _RecommendationData(icon: Icons.directions_walk_rounded, title: 'Build a steady routine', text: 'Try scheduling a few manageable workout sessions this week. Start with a duration that feels realistic for you.', tag: 'ACTIVITY'));
    } else {
      cards.add(const _RecommendationData(icon: Icons.self_improvement_rounded, title: 'Keep your momentum', text: 'You have logged several workouts recently. Keep balancing activity with rest and recovery.', tag: 'ACTIVITY'));
    }
    if (todayMeals.isEmpty) {
      cards.add(const _RecommendationData(icon: Icons.restaurant_menu_rounded, title: 'Log what you eat', text: 'Add your meals today to make your nutrition history more complete. Your totals only reflect foods you record.', tag: 'NUTRITION'));
    } else {
      cards.add(const _RecommendationData(icon: Icons.restaurant_rounded, title: 'Keep your food log updated', text: 'You have recorded meals today. Add any missing meals so your daily intake summary stays useful.', tag: 'NUTRITION'));
    }
    if (todayWorkouts.isEmpty) {
      cards.add(const _RecommendationData(icon: Icons.event_available_rounded, title: 'Make time for movement', text: 'If it fits your schedule, consider a short walk or a light session today. Adjust the intensity to how you feel.', tag: 'DAILY TIP'));
    }
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Made for your routine', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 5),
      const Text('Simple suggestions based on your logged activity — not medical advice.', style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 16),
      ...cards.map((card) => Container(margin: const EdgeInsets.only(bottom: 11), padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEAF7D9), borderRadius: BorderRadius.circular(14)), child: Icon(card.icon, color: _ink)),
          const SizedBox(width: 11), Expanded(child: Text(card.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink))),
        ]),
        const SizedBox(height: 12),
        Text(card.text, style: const TextStyle(fontSize: 12, height: 1.5, color: _muted)),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFF0F6E9), borderRadius: BorderRadius.circular(9)), child: Text(card.tag, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _ink, letterSpacing: .6))),
      ]))),
    ]);
  }
}

class _RecommendationData {
  const _RecommendationData({required this.icon, required this.title, required this.text, required this.tag});
  final IconData icon;
  final String title, text, tag;
}

class _InsightEmpty extends StatelessWidget {
  const _InsightEmpty({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title, message;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 66, height: 66, decoration: BoxDecoration(color: const Color(0xFFEAF7D9), borderRadius: BorderRadius.circular(22)), child: Icon(icon, size: 31, color: _ink)),
    const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink), textAlign: TextAlign.center),
    const SizedBox(height: 7), Text(message, style: const TextStyle(fontSize: 12, height: 1.5, color: _muted), textAlign: TextAlign.center),
  ])));
}
