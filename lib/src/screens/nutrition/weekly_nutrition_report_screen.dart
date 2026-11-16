import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../services/food_ai_service.dart';
import '../../services/nutrition_goal_service.dart';
import '../../services/nutrition_service.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _panel = Color(0xFF141B17);

class WeeklyNutritionReportScreen extends StatefulWidget {
  const WeeklyNutritionReportScreen({super.key});

  @override
  State<WeeklyNutritionReportScreen> createState() => _WeeklyNutritionReportScreenState();
}

class _WeeklyNutritionReportScreenState extends State<WeeklyNutritionReportScreen> {
  late final DateTime _weekStart;
  WeeklyNutritionInsight? _insight;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _weekStart = today.subtract(Duration(days: today.weekday - DateTime.monday));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  Future<void> _analyze(List<Meal> meals) async {
    if (_loading || meals.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _insight = null;
    });

    final daily = List.generate(7, (index) {
      final day = _weekStart.add(Duration(days: index));
      final dayMeals = meals.where((meal) => DateUtils.isSameDay(meal.date, day)).toList();
      return {
        'date': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        'mealCount': dayMeals.length,
        'calories': dayMeals.fold<int>(0, (sum, meal) => sum + meal.calories),
        'proteinGrams': dayMeals.fold<double>(0, (sum, meal) => sum + meal.proteinGrams),
        'carbsGrams': dayMeals.fold<double>(0, (sum, meal) => sum + meal.carbsGrams),
        'fatGrams': dayMeals.fold<double>(0, (sum, meal) => sum + meal.fatGrams),
      };
    }).where((day) => (day['mealCount'] as int) > 0).toList();

    try {
      final result = await FoodAiService.instance.analyzeWeeklyNutrition(
        dailyTotals: daily,
        weekLabel: '${_weekStart.year}-${_weekStart.month.toString().padLeft(2, '0')}-${_weekStart.day.toString().padLeft(2, '0')} to ${_weekEnd.subtract(const Duration(days: 1)).year}-${_weekEnd.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}-${_weekEnd.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}',
      );
      if (mounted) setState(() => _insight = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to generate the weekly report. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080D0B),
    appBar: AppBar(
      backgroundColor: const Color(0xFF080D0B),
      foregroundColor: _ink,
      title: const Text('Weekly Nutrition Report', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
    ),
    body: StreamBuilder<List<Meal>>(
      stream: NutritionService.instance.getMealsForRange(_weekStart, _weekEnd),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _lime));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load weekly meal records.', style: TextStyle(color: _muted)));
        }
        final meals = snapshot.data ?? <Meal>[];
        final days = List.generate(7, (index) {
          final date = _weekStart.add(Duration(days: index));
          final dayMeals = meals.where((meal) => DateUtils.isSameDay(meal.date, date)).toList();
          return _DayNutrition(
            date: date,
            calories: dayMeals.fold<int>(0, (sum, meal) => sum + meal.calories),
            protein: dayMeals.fold<double>(0, (sum, meal) => sum + meal.proteinGrams),
            carbs: dayMeals.fold<double>(0, (sum, meal) => sum + meal.carbsGrams),
            fat: dayMeals.fold<double>(0, (sum, meal) => sum + meal.fatGrams),
            mealCount: dayMeals.length,
          );
        });
        final loggedDays = days.where((day) => day.mealCount > 0).toList();
        final totalCalories = meals.fold<int>(0, (sum, meal) => sum + meal.calories);
        final averageCalories = loggedDays.isEmpty ? 0 : (totalCalories / loggedDays.length).round();
        final protein = meals.fold<double>(0, (sum, meal) => sum + meal.proteinGrams);
        final carbs = meals.fold<double>(0, (sum, meal) => sum + meal.carbsGrams);
        final fat = meals.fold<double>(0, (sum, meal) => sum + meal.fatGrams);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            Text(
              '${_weekStart.day} ${_month(_weekStart.month)} - ${_weekEnd.subtract(const Duration(days: 1)).day} ${_month(_weekEnd.subtract(const Duration(days: 1)).month)}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _StatCard(label: 'Total calories', value: totalCalories.toString(), unit: 'kcal')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Daily average', value: averageCalories.toString(), unit: 'kcal / logged day')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatCard(label: 'Logged meals', value: meals.length.toString(), unit: '${loggedDays.length} active days')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Protein total', value: protein.toStringAsFixed(0), unit: 'grams')),
            ]),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Calories by day',
              subtitle: 'Only days with no records show as zero',
              child: _WeeklyBarChart(days: days),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Weekly macros',
              subtitle: 'Total nutrition from logged meals',
              child: Column(children: [
                _MacroRow(label: 'Protein', value: protein, color: _lime),
                _MacroRow(label: 'Carbohydrates', value: carbs, color: const Color(0xFFFFC66D)),
                _MacroRow(label: 'Fat', value: fat, color: const Color(0xFF7BC8FF)),
              ]),
            ),
            const SizedBox(height: 14),
            StreamBuilder<NutritionGoals>(
              stream: NutritionGoalService.instance.watchGoals(),
              builder: (context, goalSnapshot) {
                final goals = goalSnapshot.data ?? const NutritionGoals();
                final target = goals.calories * 7;
                final ratio = target <= 0 ? 0.0 : (totalCalories / target).clamp(0.0, 1.0).toDouble();
                return _SectionCard(
                  title: 'Weekly calorie target',
                  subtitle: 'Compared with your daily target multiplied by seven',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('$totalCalories / $target kcal', style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800))),
                      Text('${(ratio * 100).round()}%', style: const TextStyle(color: _lime, fontSize: 13, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 9),
                    ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: const Color(0xFF29332D), valueColor: const AlwaysStoppedAnimation<Color>(_lime))),
                    const SizedBox(height: 7),
                    Text('Target: ${goals.calories} kcal per day', style: const TextStyle(color: _muted, fontSize: 10)),
                  ]),
                );
              },
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'AI weekly review',
              subtitle: 'A summary based on the meals you recorded',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_insight == null && _error == null)
                  const Text('Get a weekly overview, positive trends and practical suggestions for next week.', style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
                if (_loading) const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _lime)), SizedBox(width: 9), Text('Reviewing your week...', style: TextStyle(color: _muted, fontSize: 11))]),
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFF9B8F), fontSize: 11)),
                if (_insight case final insight?) ...[
                  Text(insight.summary, style: const TextStyle(color: _ink, fontSize: 12, height: 1.5)),
                  if (insight.highlights.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('WEEKLY HIGHLIGHTS', style: TextStyle(color: _lime, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                    ...insight.highlights.map((item) => _Bullet(text: item, color: _lime)),
                  ],
                  if (insight.recommendations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('NEXT WEEK', style: TextStyle(color: Color(0xFFFFC66D), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                    ...insight.recommendations.map((item) => _Bullet(text: item, color: const Color(0xFFFFC66D))),
                  ],
                  const SizedBox(height: 8),
                  Text(insight.disclaimer, style: const TextStyle(color: _muted, fontSize: 9)),
                ],
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _loading || meals.isEmpty ? null : () => _analyze(meals),
                  icon: _loading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(_insight == null ? 'Generate weekly AI report' : 'Generate again'),
                  style: OutlinedButton.styleFrom(foregroundColor: _lime, side: const BorderSide(color: Color(0xFF526B3B))),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('Daily breakdown', style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            ...days.map((day) => _DayRow(day: day)),
            if (meals.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 12), child: Text('No meal records found for this week yet.', style: TextStyle(color: _muted, fontSize: 12))),
          ],
        );
      },
    ),
  );

  String _month(int month) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][month - 1];
}

class _DayNutrition {
  const _DayNutrition({required this.date, required this.calories, required this.protein, required this.carbs, required this.fat, required this.mealCount});
  final DateTime date;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final int mealCount;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(17)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      const SizedBox(height: 7),
      Text(value, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800)),
      Text(unit, style: const TextStyle(color: _muted, fontSize: 9)),
    ]),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(19)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.days});
  final List<_DayNutrition> days;
  @override
  Widget build(BuildContext context) {
    final maxCalories = days.fold<int>(0, (maxValue, day) => day.calories > maxValue ? day.calories : maxValue);
    final maxValue = maxCalories < 2000 ? 2000.0 : maxCalories.toDouble();
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final ratio = day.calories == 0 ? 0.0 : (day.calories / maxValue).clamp(0.0, 1.0).toDouble();
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(day.calories == 0 ? '-' : day.calories.toString(), style: const TextStyle(color: _muted, fontSize: 8)),
              const SizedBox(height: 5),
              Expanded(child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: ratio == 0 ? 0.015 : ratio,
                  widthFactor: 0.72,
                  child: DecoratedBox(decoration: BoxDecoration(color: day.calories == 0 ? const Color(0xFF29332D) : _lime, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))),
                ),
              )),
              const SizedBox(height: 7),
              Text(_weekday(day.date.weekday), style: const TextStyle(color: _muted, fontSize: 9)),
            ]),
          ));
        }).toList(),
      ),
    );
  }
  String _weekday(int weekday) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][weekday - 1];
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 9),
      Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 11))),
      Text('${value.toStringAsFixed(1)} g', style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});
  final _DayNutrition day;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(13)),
    child: Row(children: [
      SizedBox(width: 42, child: Text(const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][day.date.weekday - 1], style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700))),
      Expanded(child: Text('${day.date.day}/${day.date.month} · ${day.mealCount} meals', style: const TextStyle(color: _muted, fontSize: 10))),
      Text(day.calories == 0 ? 'No records' : '${day.calories} kcal', style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 6, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: _ink, fontSize: 11, height: 1.4))),
    ]),
  );
}
