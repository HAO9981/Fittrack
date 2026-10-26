import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/meal.dart';
import '../../models/workout.dart';
import '../../services/nutrition_service.dart';
import '../../services/workout_service.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);

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

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({required this.workouts, required this.meals});
  final List<Workout> workouts;
  final List<Meal> meals;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final workoutEntries = widget.workouts.map((w) => _HistoryEntry(
      date: w.date,
      title: w.name,
      subtitle: '${w.category} · ${w.formattedDuration}',
      icon: Icons.fitness_center_rounded,
    )).toList();
    final mealEntries = widget.meals.map((m) => _HistoryEntry(
      date: m.date,
      title: m.foodName,
      subtitle: '${m.category} · ${m.calories} kcal',
      icon: Icons.restaurant_rounded,
    )).toList();
    final entries = <_HistoryEntry>[
      if (_filter != 'Meals') ...workoutEntries,
      if (_filter != 'Workouts') ...mealEntries,
    ]..sort((a, b) => b.date.compareTo(a.date));

    final message = _filter == 'Workouts'
        ? 'Workouts you record will appear here.'
        : _filter == 'Meals'
            ? 'Meals you record will appear here.'
            : 'Workouts and meals you record will appear here.';

    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 5),
      const Text('Review your recorded activity by category.', style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 14),
      _HistoryFilter(selected: _filter, onChanged: (value) => setState(() => _filter = value)),
      const SizedBox(height: 16),
      if (entries.isEmpty)
        _InsightEmpty(
          icon: _filter == 'Meals' ? Icons.restaurant_rounded : Icons.history_rounded,
          title: 'No records yet',
          message: message,
        )
      else
        ...entries.take(100).map((entry) => Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF202922), borderRadius: BorderRadius.circular(14)), child: Icon(entry.icon, color: _ink)),
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

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = ['All', 'Workouts', 'Meals'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: _options.map((option) {
      final active = selected == option;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(option),
          selected: active,
          onSelected: (_) => onChanged(option),
          selectedColor: _lime,
          backgroundColor: const Color(0xFF141B17),
          side: BorderSide.none,
          showCheckmark: false,
          shape: const StadiumBorder(),
          labelStyle: TextStyle(color: active ? const Color(0xFF080D0B) : _ink, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
        ),
      );
    }).toList()),
  );
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
      return workouts.where((w) => DateUtils.isSameDay(w.date, day)).fold<int>(0, (sum, w) => sum + w.durationInMinutes);
    });
    final maxMinutes = minutes.fold<int>(0, (max, value) => value > max ? value : max);
    final weekMeals = meals.where((m) => !DateUtils.dateOnly(m.date).isBefore(today.subtract(const Duration(days: 6)))).toList();
    final weekWorkouts = workouts.where((w) => !DateUtils.dateOnly(w.date).isBefore(today.subtract(const Duration(days: 6)))).toList();
    final totalMinutes = weekWorkouts.fold<int>(0, (sum, w) => sum + w.durationInMinutes);
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
      const _WeightProgressCard(),
      const SizedBox(height: 12),
      const _TargetWeightCard(),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daily workout minutes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 20),
        SizedBox(height: 125, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) {
          final height = maxMinutes == 0 ? 8.0 : (minutes[i] / maxMinutes * 84).clamp(8.0, 84.0).toDouble();
          final day = today.subtract(Duration(days: 6 - i));
          final active = DateUtils.isSameDay(day, today);
          return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(minutes[i].toString(), style: const TextStyle(fontSize: 9, color: _muted)),
            const SizedBox(height: 5),
            Container(height: height, width: 15, decoration: BoxDecoration(color: minutes[i] > 0 ? _lime : const Color(0xFF27332B), borderRadius: BorderRadius.circular(8))),
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


class _WeightProgressCard extends StatelessWidget {
  const _WeightProgressCard();

  Future<void> _logWeight(BuildContext context, String uid) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log today\'s weight'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (kg)', hintText: 'e.g. 72.5'),
            validator: (text) {
              final weight = double.tryParse((text ?? '').trim());
              if (weight == null || weight < 20 || weight > 400) return 'Enter a valid weight (20–400 kg).';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _muted),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, double.parse(controller.text.trim()));
              }
            },
            child: const Text('Save weight'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDoc.collection('weightEntries').add({
        'weightKg': value,
        'recordedAt': FieldValue.serverTimestamp(),
      });
      final userSnapshot = await userDoc.get();
      final profileData = userSnapshot.data() ?? <String, dynamic>{};
      final updates = <String, dynamic>{
        'weightKg': value,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (profileData['startingWeightKg'] == null) {
        updates['startingWeightKg'] = value;
      }
      await userDoc.set(updates, SetOptions(merge: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight saved.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save weight. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _WeightCardMessage(message: 'Sign in to track your weight history.');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('weightEntries').orderBy('recordedAt').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _WeightCardMessage(message: 'Weight history is temporarily unavailable.');
        final entries = (snapshot.data?.docs ?? []).map((doc) {
          final weight = (doc.data()['weightKg'] as num?)?.toDouble();
          final stamp = doc.data()['recordedAt'];
          final date = stamp is Timestamp ? stamp.toDate() : null;
          if (weight == null || date == null) return null;
          return (weight: weight, date: date);
        }).whereType<({double weight, DateTime date})>().toList();
        final userWeight = (snapshot.data?.docs.isNotEmpty ?? false)
            ? entries.isNotEmpty ? entries.last.weight : null
            : null;
        if (entries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Weight progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 7),
              const Text('Start tracking your body weight to see how it changes over time.', style: TextStyle(fontSize: 12, height: 1.5, color: _muted)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _logWeight(context, user.uid),
                style: OutlinedButton.styleFrom(foregroundColor: _ink, side: const BorderSide(color: Color(0xFFD9DED5))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Log weight'),
              ),
            ]),
          );
        }
        final first = entries.first.weight;
        final latest = userWeight ?? entries.last.weight;
        final change = latest - first;
        final changeLabel = change.abs() < 0.05 ? 'No change yet' : '${change < 0 ? 'Down' : 'Up'} ${change.abs().toStringAsFixed(1)} kg since first entry';
        final chartEntries = entries.length > 12 ? entries.sublist(entries.length - 12) : entries;
        final minWeight = chartEntries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
        final maxWeight = chartEntries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
        final range = maxWeight - minWeight;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Weight progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 5),
            const Text('Log your weight here whenever you want to check your progress.', style: TextStyle(fontSize: 11, color: _muted)),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current', style: TextStyle(fontSize: 11, color: _muted)),
                Text('${latest.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Starting', style: TextStyle(fontSize: 11, color: _muted)),
                Text('${first.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
              ])),
            ]),
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF202922), borderRadius: BorderRadius.circular(14)),
              child: Text(changeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink))),
            if (chartEntries.length > 1) ...[
              const SizedBox(height: 16),
              const Text('Recent weight history (kg)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 12),
              SizedBox(height: 88, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: chartEntries.map((entry) {
                final height = range == 0 ? 36.0 : 24 + ((entry.weight - minWeight) / range * 48);
                return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(entry.weight.toStringAsFixed(1), style: const TextStyle(fontSize: 8, color: _muted)),
                  const SizedBox(height: 4),
                  Container(height: height.toDouble(), decoration: BoxDecoration(color: const Color(0xFF9AA197), borderRadius: BorderRadius.circular(6))),
                ])));
              }).toList())),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _logWeight(context, user.uid),
              style: OutlinedButton.styleFrom(foregroundColor: _ink, side: const BorderSide(color: Color(0xFFD9DED5))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log weight'),
            ),
          ]),
        );
      },
    );
  }
}

class _TargetWeightCard extends StatelessWidget {
  const _TargetWeightCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final current = (data?['weightKg'] as num?)?.toDouble();
        final target = (data?['targetWeightKg'] as num?)?.toDouble();
        if (target == null || target <= 0) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Target weight', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              SizedBox(height: 6),
              Text('Set a target weight in Profile to see how far you are from your goal.', style: TextStyle(fontSize: 12, height: 1.5, color: _muted)),
            ]),
          );
        }
        final hasCurrent = current != null && current > 0;
        final difference = hasCurrent ? (current - target).abs() : null;
        final start = (data?['startingWeightKg'] as num?)?.toDouble();
        final baseline = start ?? current;
        final totalToTarget = baseline != null ? (baseline - target).abs() : null;
        final progress = hasCurrent && totalToTarget != null && totalToTarget > 0
            ? ((baseline! - current!).abs() / totalToTarget).clamp(0.0, 1.0).toDouble()
            : (hasCurrent && difference! < 0.05 ? 1.0 : 0.0);
        final reached = difference != null && difference < 0.05;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Target weight', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current', style: TextStyle(fontSize: 11, color: _muted)),
                Text(hasCurrent ? '${current.toStringAsFixed(1)} kg' : 'Not set', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Goal', style: TextStyle(fontSize: 11, color: _muted)),
                Text('${target.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink)),
              ])),
            ]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: const Color(0xFF27332B), valueColor: const AlwaysStoppedAnimation<Color>(_lime))),
            const SizedBox(height: 8),
            Text(!hasCurrent ? 'Log your current weight to begin.' : reached ? 'Target reached — great work!' : '${difference!.toStringAsFixed(1)} kg from your target', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
          ]),
        );
      },
    );
  }
}

class _WeightCardMessage extends StatelessWidget {
  const _WeightCardMessage({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Weight progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 8),
      Text(message, style: const TextStyle(fontSize: 12, height: 1.5, color: _muted)),
    ]),
  );
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.title, required this.value, required this.unit, required this.icon});
  final String title, value, unit;
  final IconData icon;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(19)), child: Row(children: [
    Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF202922), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: _ink)),
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
      ...cards.map((card) => Container(margin: const EdgeInsets.only(bottom: 11), padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(21)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(14)), child: Icon(card.icon, color: _ink)),
          const SizedBox(width: 11), Expanded(child: Text(card.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink))),
        ]),
        const SizedBox(height: 12),
        Text(card.text, style: const TextStyle(fontSize: 12, height: 1.5, color: _muted)),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF202922), borderRadius: BorderRadius.circular(9)), child: Text(card.tag, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _ink, letterSpacing: .6))),
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
    Container(width: 66, height: 66, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(22)), child: Icon(icon, size: 31, color: _ink)),
    const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink), textAlign: TextAlign.center),
    const SizedBox(height: 7), Text(message, style: const TextStyle(fontSize: 12, height: 1.5, color: _muted), textAlign: TextAlign.center),
  ])));
}
