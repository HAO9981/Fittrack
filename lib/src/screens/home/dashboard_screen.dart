import 'package:flutter/material.dart';
import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/app_empty_state.dart';
import '../workout/add_workout_screen.dart';
import '../nutrition/add_meal_screen.dart';
import '../insights/insights_screen.dart';
import '../ai/ai_assistant_screen.dart';

const lime = Color(0xFF9BFF3D), ink = Color(0xFFF4F7F1), muted = Color(0xFF9AA69C), bg = Color(0xFF080D0B), surface = Color(0xFF141B17), border = Color(0xFF27332B);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService.instance.currentUser;
    final authName = user?.displayName?.trim() ?? '';
    return StreamBuilder<UserProfile?>(
      stream: user == null ? const Stream<UserProfile?>.empty() : FirestoreService.instance.userProfileStream(user.uid),
      builder: (context, profileSnapshot) {
        final savedName = profileSnapshot.data?.displayName.trim() ?? '';
        final raw = savedName.isNotEmpty && savedName != 'FitTrack User' ? savedName : authName;
        final name = raw.isEmpty ? 'there' : raw.split(' ').first;
        return Scaffold(backgroundColor: bg, body: SafeArea(child: StreamBuilder<List<Workout>>(
      stream: WorkoutService.instance.getWorkouts(),
      builder: (context, ws) => StreamBuilder<List<Meal>>(
        stream: NutritionService.instance.getMeals(),
        builder: (context, ms) {
          if (ws.connectionState == ConnectionState.waiting || ms.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: lime));
          if (ws.hasError || ms.hasError) return const AppEmptyState(icon: Icons.cloud_off_outlined, title: 'Dashboard unavailable', message: 'Your latest activity could not be loaded.');
          return _DashboardContent(name: name, profile: profileSnapshot.data, workouts: ws.data ?? const [], meals: ms.data ?? const []);
        },
      ),
    )));
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.name, required this.profile, required this.workouts, required this.meals});
  final String name;
  final UserProfile? profile;
  final List<Workout> workouts;
  final List<Meal> meals;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(), today = DateUtils.dateOnly(DateTime.now());
    final todaysWorkouts = workouts.where((w) => DateUtils.isSameDay(w.date, today)).toList();
    final todaysMeals = meals.where((m) => DateUtils.isSameDay(m.date, today)).toList();
    final weekly = workouts.where((w) => !DateUtils.dateOnly(w.date).isBefore(today.subtract(const Duration(days: 6)))).toList();
    final mins = todaysWorkouts.fold<int>(0, (s, w) => s + w.durationInMinutes);
    final cals = todaysMeals.fold<int>(0, (s, m) => s + m.calories);
    final greeting = now.hour < 12 ? 'Good morning,' : now.hour < 18 ? 'Good afternoon,' : 'Good evening,';
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 18), children: [
      Row(children: [
        const Expanded(child: Text('FitTrack', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.4))),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You’re all caught up!'))),
          icon: const Icon(Icons.notifications_none_rounded, color: ink),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF263522),
            border: Border.all(color: lime.withValues(alpha: 0.28)),
          ),
          child: Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: lime, fontSize: 16, fontWeight: FontWeight.w800))),
        ),
      ]),
      const SizedBox(height: 10),
      Text(greeting, style: const TextStyle(color: muted, fontSize: 13)),
      const SizedBox(height: 2),
      Text('$name!', style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.5)),
      const SizedBox(height: 5),
      Text(MaterialLocalizations.of(context).formatFullDate(now), style: const TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: border), gradient: const LinearGradient(colors: [Color(0xFF1B261C), Color(0xFF111813)])),
        child: Row(children: [
          SizedBox(width: 88, height: 88, child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: (mins / 60).clamp(0.0, 1.0), strokeWidth: 9, backgroundColor: const Color(0xFF34452E), valueColor: const AlwaysStoppedAnimation<Color>(lime), strokeCap: StrokeCap.round)),
            Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.directions_run_rounded, size: 27, color: lime), const SizedBox(height: 2), Text('${((mins / 60).clamp(0.0, 1.0) * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ink))]),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Today's Activity", style: TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 7), Text('$mins min', style: const TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.w800)), const SizedBox(height: 2), const Text('of 60 min daily goal', style: TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 7), Text('$cals kcal logged', style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 5), Text('${todaysWorkouts.length} workout(s) completed', style: const TextStyle(color: ink, fontSize: 11))])),
        ]),
      ),
      const SizedBox(height: 12),
      if (profile?.weightKg != null || profile?.targetWeightKg != null) ...[
        _WeightGoalOverview(currentWeight: profile?.weightKg, targetWeight: profile?.targetWeightKg),
        const SizedBox(height: 12),
      ],
      Row(children: [Expanded(child: _Stat(icon: Icons.local_fire_department_rounded, color: lime, value: '$cals', label: 'Calories')), const SizedBox(width: 10), Expanded(child: _Stat(icon: Icons.access_time_rounded, color: lime, value: '$mins', label: 'Mins')), const SizedBox(width: 10), Expanded(child: _Stat(icon: Icons.fitness_center_rounded, color: lime, value: todaysWorkouts.length.toString(), label: 'Workouts'))]),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Weekly Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)), Text(weekly.fold<int>(0, (s, w) => s + w.durationInMinutes).toString() + ' min', style: const TextStyle(fontWeight: FontWeight.w700))]),
      const SizedBox(height: 10), _Chart(workouts: weekly, today: today),
      const SizedBox(height: 18),
      InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF25351D),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: ink),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ask FitTrack AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
                SizedBox(height: 4),
                Text('Get workout and nutrition advice', style: TextStyle(fontSize: 11, color: muted)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      const Text('Quick Actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Action(icon: Icons.fitness_center_rounded, label: 'Log Workout', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddWorkoutScreen())))),
        const SizedBox(width: 9), Expanded(child: _Action(icon: Icons.restaurant_rounded, label: 'Log Food', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMealScreen())))),
        const SizedBox(width: 9), Expanded(child: _Action(icon: Icons.auto_awesome_rounded, label: 'FitTrack AI', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiAssistantScreen())))),
      ]),
      const SizedBox(height: 22), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Recent Workouts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)), Text('${workouts.length} total', style: const TextStyle(fontSize: 11, color: muted))]), const SizedBox(height: 8),
      if (workouts.isEmpty) const _Empty(text: 'Your workouts will appear here.') else ...workouts.take(3).map((w) => _Recent(icon: _workoutIcon(w.category), title: w.name, subtitle: '${w.category}  •  ${w.formattedDuration}', trailing: _formatRecentDate(w.date))),
      const SizedBox(height: 14), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Recent Meals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)), Text('${meals.length} total', style: const TextStyle(fontSize: 11, color: muted))]), const SizedBox(height: 8),
      if (meals.isEmpty) const _Empty(text: 'Your meals will appear here.') else ...meals.take(3).map((m) => _Recent(icon: Icons.restaurant_rounded, title: m.foodName, subtitle: '${m.category}  •  ${m.calories} kcal', trailing: _formatRecentDate(m.date))),
      const SizedBox(height: 14),
      InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsightsScreen())),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: border.withValues(alpha: 0.55))),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.insights_rounded, color: lime)),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('History, Progress & Tips', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
              SizedBox(height: 3),
              Text('Review your activity and see suggestions', style: TextStyle(fontSize: 11, color: muted)),
            ])),
            Icon(Icons.chevron_right_rounded, color: muted),
          ]),
        ),
      ),
      TextButton.icon(onPressed: () => FirebaseAuthService.instance.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
    ]);
  }
}

class _WeightGoalOverview extends StatelessWidget {
  const _WeightGoalOverview({required this.currentWeight, required this.targetWeight});
  final double? currentWeight;
  final double? targetWeight;

  @override
  Widget build(BuildContext context) {
    final hasCurrent = currentWeight != null && currentWeight! > 0;
    final hasTarget = targetWeight != null && targetWeight! > 0;
    final difference = hasCurrent && hasTarget ? (currentWeight! - targetWeight!).abs() : null;
    final reached = difference != null && difference < 0.05;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: border.withValues(alpha: 0.55))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.monitor_weight_outlined, color: lime)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Weight goal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 4),
          Text(
            !hasCurrent ? 'Add your current weight in Profile' : !hasTarget ? 'Set a target weight in Profile' : reached ? 'Target reached — great work!' : '${currentWeight!.toStringAsFixed(1)} kg now · ${targetWeight!.toStringAsFixed(1)} kg target',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          if (difference != null && !reached) ...[
            const SizedBox(height: 5),
            Text('${difference.toStringAsFixed(1)} kg to your target', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
          ],
        ])),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.flag_outlined, color: lime, size: 18)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon; final Color color; final String value, label;
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: border.withValues(alpha: 0.55))),
    child: Column(children: [
      Icon(icon, color: color, size: 21),
      const SizedBox(height: 7),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: ink)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
    ]),
  );
}

class _Chart extends StatelessWidget {
  const _Chart({required this.workouts, required this.today});
  final List<Workout> workouts;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = List<DateTime>.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final totals = days.map((day) => workouts
        .where((workout) => DateUtils.isSameDay(workout.date, day))
        .fold<int>(0, (sum, workout) => sum + workout.durationInMinutes)).toList();
    final maxMinutes = totals.fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
    final hasActivity = maxMinutes > 0;
    return Container(
      height: 154,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final minutes = totals[index];
                final fraction = maxMinutes == 0 ? 0.0 : minutes / maxMinutes;
                final barHeight = hasActivity ? (fraction * 72).clamp(8.0, 72.0).toDouble() : 8.0;
                final isToday = DateUtils.isSameDay(days[index], today);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (minutes > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('$minutes', style: const TextStyle(fontSize: 9, color: muted, fontWeight: FontWeight.w600)),
                          ),
                        Container(
                          height: 76,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: barHeight,
                            width: 13,
                            decoration: BoxDecoration(
                              color: minutes > 0 ? lime : const Color(0xFF303A33),
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: minutes > 0 ? [BoxShadow(color: lime.withValues(alpha: 0.13), blurRadius: 8)] : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: List.generate(7, (index) => Expanded(
              child: Center(
                child: Text(
                  ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][days[index].weekday - 1],
                  style: TextStyle(fontSize: 10, color: DateUtils.isSameDay(days[index], today) ? lime : muted, fontWeight: DateUtils.isSameDay(days[index], today) ? FontWeight.w700 : FontWeight.w400),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 92, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: border.withValues(alpha: 0.55))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: lime)), const SizedBox(height: 7), Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ink))])));
}

IconData _workoutIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('run') || value.contains('cardio')) return Icons.directions_run_rounded;
  if (value.contains('cycle') || value.contains('bike')) return Icons.directions_bike_rounded;
  if (value.contains('yoga') || value.contains('stretch')) return Icons.self_improvement_rounded;
  if (value.contains('swim')) return Icons.pool_rounded;
  return Icons.fitness_center_rounded;
}

String _formatRecentDate(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(date);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${date.day}/${date.month}';
}

class _Recent extends StatelessWidget {
  const _Recent({required this.icon, required this.title, required this.subtitle, required this.trailing});
  final IconData icon;
  final String title, subtitle, trailing;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: border.withValues(alpha: 0.45))),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: lime, size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 4),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: muted)),
      ])),
      const SizedBox(width: 8),
      Text(trailing, style: const TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text}); final String text;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)), child: Text(text, style: const TextStyle(color: muted)));
}
