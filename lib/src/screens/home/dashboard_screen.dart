import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../services/auth_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_empty_state.dart';

const _lime = Color(0xFF84E221);
const _ink = Color(0xFF232824);
const _muted = Color(0xFF858C83);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService.instance.currentUser;
    return Scaffold(body: SafeArea(child: StreamBuilder<List<Workout>>(
      stream: WorkoutService.instance.getWorkouts(),
      builder: (context, ws) => StreamBuilder<List<Meal>>(
        stream: NutritionService.instance.getMeals(),
        builder: (context, ms) {
          if (ws.connectionState == ConnectionState.waiting || ms.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _lime));
          }
          if (ws.hasError || ms.hasError) return const AppEmptyState(icon: Icons.cloud_off_outlined, title: 'Dashboard unavailable', message: 'Your latest activity could not be loaded.');
          final name = (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName!.trim().split(' ').first : 'there';
          return _DashboardContent(userName: name, workouts: ws.data ?? const [], meals: ms.data ?? const []);
        },
      ),
    )));
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.userName, required this.workouts, required this.meals});
  final String userName;
  final List<Workout> workouts;
  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayWorkouts = workouts.where((w) => DateUtils.isSameDay(w.date, now)).toList();
    final todayMeals = meals.where((m) => DateUtils.isSameDay(m.date, now)).toList();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekWorkouts = workouts.where((w) => !w.date.isBefore(weekStart)).toList();
    final minutes = todayWorkouts.fold<int>(0, (sum, w) => sum + w.duration);
    final eaten = todayMeals.fold<int>(0, (sum, m) => sum + m.calories);
    final greeting = now.hour < 12 ? 'Good morning,' : now.hour < 18 ? 'Good afternoon,' : 'Good evening,';
    final dayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dailyMinutes = List<int>.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return workouts.where((w) => DateUtils.isSameDay(w.date, day)).fold<int>(0, (sum, w) => sum + w.duration);
    });
    final maxMinutes = math.max(30, dailyMinutes.fold<int>(0, (a, b) => math.max(a, b)));

    return ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting, style: const TextStyle(fontSize: 14, color: _muted)),
          const SizedBox(height: 3),
          Text('$userName!', style: const TextStyle(fontSize: 29, height: 1.05, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.8)),
        ])),
        const _RoundIcon(icon: Icons.notifications_none_rounded),
        const SizedBox(width: 10),
        CircleAvatar(radius: 22, backgroundColor: const Color(0xFFE4E9DE), child: Text(userName[0].toUpperCase(), style: const TextStyle(color: _ink, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(26)), child: Row(children: [
        SizedBox(width: 108, height: 108, child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 102, height: 102, child: CircularProgressIndicator(value: (minutes / 60).clamp(0.0, 1.0), strokeWidth: 9, backgroundColor: Colors.white.withValues(alpha: 0.12), valueColor: const AlwaysStoppedAnimation(_lime), strokeCap: StrokeCap.round)),
          Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.directions_run_rounded, color: Colors.white, size: 25), const SizedBox(height: 4), Text('$minutes', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)), const Text('of 60 min', style: TextStyle(color: Colors.white70, fontSize: 10))]),
        ])),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("TODAY'S ACTIVITY", style: TextStyle(color: Color(0xFFB9C0B7), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Keep moving.', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 7),
          Text(minutes >= 60 ? 'Daily activity goal reached!' : '${60 - minutes} more minutes to reach your goal.', style: const TextStyle(color: Color(0xFFD0D5CD), fontSize: 12, height: 1.4)),
        ])),
      ])),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _MetricCard(icon: Icons.local_fire_department_rounded, iconColor: const Color(0xFFFFA44A), label: 'Active', value: '$minutes', unit: 'min')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(icon: Icons.restaurant_rounded, iconColor: const Color(0xFF82C84A), label: 'Consumed', value: '$eaten', unit: 'kcal')),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(icon: Icons.fitness_center_rounded, iconColor: _ink, label: 'Workouts', value: '${todayWorkouts.length}', unit: 'today')),
      ]),
      const SizedBox(height: 27),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('Weekly activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.4)),
        Text('${weekWorkouts.length} workouts', style: const TextStyle(fontSize: 12, color: _muted)),
      ]),
      const SizedBox(height: 13),
      Container(padding: const EdgeInsets.fromLTRB(16, 18, 16, 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) {
        final active = i == now.weekday - 1;
        final fraction = dailyMinutes[i] / maxMinutes;
        return Expanded(child: Column(children: [
          SizedBox(height: 100, child: Align(alignment: Alignment.bottomCenter, child: Container(width: 18, height: math.max(8.0, 82 * fraction), decoration: BoxDecoration(color: active ? _lime : const Color(0xFFE5E9E1), borderRadius: BorderRadius.circular(10))))),
          const SizedBox(height: 10),
          Text(dayLabels[i], style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? _ink : _muted)),
        ]));
      }))),
      const SizedBox(height: 26),
      const Text('Quick actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.4)),
      const SizedBox(height: 13),
      const Row(children: [
        Expanded(child: _QuickAction(icon: Icons.directions_run_rounded, label: 'Add workout')),
        SizedBox(width: 10), Expanded(child: _QuickAction(icon: Icons.restaurant_rounded, label: 'Log a meal')),
        SizedBox(width: 10), Expanded(child: _QuickAction(icon: Icons.center_focus_strong_rounded, label: 'Analyze food')),
      ]),
      const SizedBox(height: 27),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Recent workouts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.4)),
        Text('${workouts.length} total', style: const TextStyle(fontSize: 12, color: _muted)),
      ]),
      const SizedBox(height: 10),
      if (workouts.isEmpty) const AppEmptyState(icon: Icons.fitness_center_outlined, title: 'No workouts yet', message: 'Your workouts will show up here.')
      else ...workouts.take(3).map((w) => _RecentTile(icon: Icons.fitness_center_rounded, title: w.name, subtitle: '${w.category} · ${w.duration} min', trailing: '${w.duration} min')),
      const SizedBox(height: 20),
      const Text('Recent meals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.4)),
      const SizedBox(height: 10),
      if (meals.isEmpty) const AppEmptyState(icon: Icons.restaurant_outlined, title: 'No meals yet', message: 'Your meal log will show up here.')
      else ...meals.take(3).map((m) => _RecentTile(icon: Icons.restaurant_rounded, title: m.foodName, subtitle: m.category, trailing: '${m.calories} kcal')),
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.iconColor, required this.label, required this.value, required this.unit});
  final IconData icon; final Color iconColor; final String label; final String value; final String unit;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: iconColor, size: 20), const SizedBox(height: 12),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5)),
    const SizedBox(height: 2), Text(unit, style: const TextStyle(fontSize: 10, color: _muted)),
    const SizedBox(height: 7), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _ink, fontWeight: FontWeight.w600)),
  ]));
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: _ink, size: 24)),
    const SizedBox(height: 7), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: _ink, fontWeight: FontWeight.w600)),
  ]);
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.icon, required this.title, required this.subtitle, required this.trailing});
  final IconData icon; final String title; final String subtitle; final String trailing;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF0F3EC), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _ink, size: 21)),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
      const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
    ])),
    const SizedBox(width: 8), Text(trailing, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
  ]));
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(width: 42, height: 42, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: _ink, size: 22));
}
