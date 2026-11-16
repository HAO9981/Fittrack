import 'package:flutter/material.dart';
import '../../models/meal.dart';
import '../../services/auth_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/food_ai_service.dart';
import '../../services/nutrition_goal_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_meal_screen.dart';
import 'edit_meal_screen.dart';
import '../../navigation/app_navigation.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override State<NutritionScreen> createState() => _NutritionScreenState();
}
class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  Future<void> _chooseDate() async {
    final chosen = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (chosen != null && mounted) setState(() => _date = DateUtils.dateOnly(chosen));
  }
  void _moveDate(int days) {
    final next = _date.add(Duration(days: days));
    if (!next.isAfter(DateUtils.dateOnly(DateTime.now()))) setState(() => _date = next);
  }
  void _addMeal() {
    if (FirebaseAuthService.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to add a meal.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMealScreen()));
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(child: StreamBuilder<List<Meal>>(
      stream: NutritionService.instance.getMealsByDate(_date),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _lime));
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.error is StateError ? 'Please sign in to view your nutrition records.' : 'Unable to load nutrition records. Please try again.', textAlign: TextAlign.center)));
        final meals = snapshot.data ?? <Meal>[];
        final total = meals.fold<int>(0, (sum, meal) => sum + meal.calories);
        final today = DateUtils.isSameDay(_date, DateTime.now());
        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 100), children: [
          Row(children: [IconButton(tooltip: 'Open navigation menu', onPressed: AppNavigation.openDrawer, icon: const Icon(Icons.menu_rounded, color: _ink)), const Expanded(child: Text('Nutrition', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink))), IconButton(onPressed: _chooseDate, tooltip: 'Choose date', icon: const Icon(Icons.calendar_month_rounded, color: _ink))]),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(18)), child: Row(children: [
            IconButton(onPressed: () => _moveDate(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: InkWell(onTap: _chooseDate, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(today ? 'Today' : MaterialLocalizations.of(context).formatMediumDate(_date), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink))))),
            IconButton(onPressed: today ? null : () => _moveDate(1), icon: const Icon(Icons.chevron_right_rounded)),
          ])),
          const SizedBox(height: 16),
          _DailyCalorieCard(total: total),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _MealCategory(icon: Icons.wb_sunny_outlined, title: 'Breakfast', calories: _categoryTotal(meals, 'Breakfast'), color: const Color(0xFFFFF0D9))),
            const SizedBox(width: 8),
            Expanded(child: _MealCategory(icon: Icons.lunch_dining_outlined, title: 'Lunch', calories: _categoryTotal(meals, 'Lunch'), color: const Color(0xFF25351D))),
            const SizedBox(width: 8),
            Expanded(child: _MealCategory(icon: Icons.nights_stay_outlined, title: 'Dinner', calories: _categoryTotal(meals, 'Dinner'), color: const Color(0xFFE7F1F0))),
          ]),
          const SizedBox(height: 14),
          _MacroSummary(
            protein: meals.fold<double>(0, (sum, meal) => sum + meal.proteinGrams),
            carbs: meals.fold<double>(0, (sum, meal) => sum + meal.carbsGrams),
            fat: meals.fold<double>(0, (sum, meal) => sum + meal.fatGrams),
          ),
          const SizedBox(height: 12),
          _NutritionGoalsCard(
            calories: total,
            protein: meals.fold<double>(0, (sum, meal) => sum + meal.proteinGrams),
            carbs: meals.fold<double>(0, (sum, meal) => sum + meal.carbsGrams),
            fat: meals.fold<double>(0, (sum, meal) => sum + meal.fatGrams),
          ),
          const SizedBox(height: 12),
          _DailyAiNutritionCard(meals: meals, date: _date),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(today ? "Today's Meals" : 'Meals', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)), Text(meals.length.toString() + ' items', style: const TextStyle(fontSize: 12, color: _muted))]),
          const SizedBox(height: 10),
          if (meals.isEmpty) const AppEmptyState(icon: Icons.restaurant_outlined, title: 'No meals recorded', message: 'Add a meal to start tracking calories for this date.') else ...meals.map((meal) => _MealCard(meal: meal)),
          const SizedBox(height: 10),
          SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _addMeal, icon: const Icon(Icons.add_rounded), label: const Text('Add Meal'))),
        ]);
      },
    )),
  );
}

int _categoryTotal(List<Meal> meals, String category) => meals.where((m) => m.category == category).fold<int>(0, (sum, m) => sum + m.calories);

class _DailyCalorieCard extends StatelessWidget {
  const _DailyCalorieCard({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) => StreamBuilder<NutritionGoals>(
    stream: NutritionGoalService.instance.watchGoals(),
    builder: (context, snapshot) {
      final goal = snapshot.data?.calories ?? 2000;
      final remaining = (goal - total).clamp(0, goal);
      final progress = goal <= 0 ? 0.0 : (total / goal).clamp(0.0, 1.0).toDouble();
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          SizedBox(width: 124, height: 124, child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: progress, strokeWidth: 10, backgroundColor: const Color(0xFF27332B), valueColor: const AlwaysStoppedAnimation<Color>(_lime))),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFA52D), size: 20),
              const SizedBox(height: 3),
              Text(total.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
              Text('of $goal kcal', style: const TextStyle(fontSize: 10, color: _muted)),
            ]),
          ])),
          const SizedBox(width: 17),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Daily intake', style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 5),
            Text(remaining.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink)),
            const Text('kcal remaining', style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 9),
            Text(total >= goal ? 'Daily goal reached' : 'Keep logging meals', style: const TextStyle(fontSize: 11, color: _muted)),
          ])),
        ]),
      );
    },
  );
}

class _NutritionGoalsCard extends StatelessWidget {
  const _NutritionGoalsCard({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  Future<void> _editGoals(BuildContext context, NutritionGoals goals) async {
    final caloriesController = TextEditingController(text: goals.calories.toString());
    final proteinController = TextEditingController(text: goals.proteinGrams.toStringAsFixed(0));
    final carbsController = TextEditingController(text: goals.carbsGrams.toStringAsFixed(0));
    final fatController = TextEditingController(text: goals.fatGrams.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<NutritionGoals>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Daily nutrition goals'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _goalInput(caloriesController, 'Calories (kcal)', 500, 10000, true),
            _goalInput(proteinController, 'Protein (g)', 0, 500, false),
            _goalInput(carbsController, 'Carbs (g)', 0, 1000, false),
            _goalInput(fatController, 'Fat (g)', 0, 500, false),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, NutritionGoals(
                calories: int.parse(caloriesController.text),
                proteinGrams: double.parse(proteinController.text),
                carbsGrams: double.parse(carbsController.text),
                fatGrams: double.parse(fatController.text),
              ));
            },
            child: const Text('Save goals'),
          ),
        ],
      ),
    );

    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    if (updated == null) return;
    try {
      await NutritionGoalService.instance.saveGoals(updated);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save nutrition goals. Please try again.')),
        );
      }
    }
  }

  static Widget _goalInput(
    TextEditingController controller,
    String label,
    double min,
    double max,
    bool integer,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final number = double.tryParse(value ?? '');
        if (number == null || number < min || number > max ||
            (integer && number != number.roundToDouble())) {
          return 'Enter a value from $min to $max.';
        }
        return null;
      },
    ),
  );

  Widget _progress(String label, double current, double target, String unit, Color color) {
    final ratio = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: _ink, fontWeight: FontWeight.w600))),
          Text('${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit', style: const TextStyle(fontSize: 10, color: _muted)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(value: ratio, minHeight: 7, backgroundColor: const Color(0xFF29332D), valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<NutritionGoals>(
    stream: NutritionGoalService.instance.watchGoals(),
    builder: (context, snapshot) {
      final goals = snapshot.data ?? const NutritionGoals();
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(19)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Daily Goals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
              Text('Track your intake against your targets', style: TextStyle(fontSize: 10, color: _muted)),
            ])),
            IconButton(
              tooltip: 'Edit nutrition goals',
              onPressed: () => _editGoals(context, goals),
              icon: const Icon(Icons.tune_rounded, color: _lime, size: 20),
            ),
          ]),
          _progress('Calories', calories.toDouble(), goals.calories.toDouble(), 'kcal', _lime),
          _progress('Protein', protein, goals.proteinGrams, 'g', const Color(0xFF9BFF3D)),
          _progress('Carbs', carbs, goals.carbsGrams, 'g', const Color(0xFFFFC66D)),
          _progress('Fat', fat, goals.fatGrams, 'g', const Color(0xFF7BC8FF)),
          const SizedBox(height: 8),
          const Text('Default targets are general starting points. Adjust them to your needs.', style: TextStyle(fontSize: 9, color: _muted)),
        ]),
      );
    },
  );
}

class _DailyAiNutritionCard extends StatefulWidget {
  const _DailyAiNutritionCard({required this.meals, required this.date});
  final List<Meal> meals;
  final DateTime date;

  @override
  State<_DailyAiNutritionCard> createState() => _DailyAiNutritionCardState();
}

class _DailyAiNutritionCardState extends State<_DailyAiNutritionCard> {
  DailyNutritionInsight? _insight;
  bool _loading = false;
  String? _error;

  Future<void> _analyze() async {
    if (_loading || widget.meals.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _insight = null;
    });
    final protein = widget.meals.fold<double>(0, (sum, meal) => sum + meal.proteinGrams);
    final carbs = widget.meals.fold<double>(0, (sum, meal) => sum + meal.carbsGrams);
    final fat = widget.meals.fold<double>(0, (sum, meal) => sum + meal.fatGrams);
    final calories = widget.meals.fold<int>(0, (sum, meal) => sum + meal.calories);
    try {
      final result = await FoodAiService.instance.analyzeDailyNutrition(
        meals: widget.meals.map((meal) => {
          'foodName': meal.foodName,
          'category': meal.category,
          'calories': meal.calories,
          'proteinGrams': meal.proteinGrams,
          'carbsGrams': meal.carbsGrams,
          'fatGrams': meal.fatGrams,
          'portion': meal.portion ?? 'Not recorded',
        }).toList(),
        totalCalories: calories,
        proteinGrams: protein,
        carbsGrams: carbs,
        fatGrams: fat,
        dateLabel: MaterialLocalizations.of(context).formatMediumDate(widget.date),
      );
      if (mounted) setState(() => _insight = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to generate insights. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant _DailyAiNutritionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.date, widget.date) ||
        oldWidget.meals != widget.meals) {
      _insight = null;
      _error = null;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF141B17),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFF34432F)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFF26351F), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.auto_awesome_rounded, color: _lime, size: 19)),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FitTrack AI Nutrition', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
          Text('Personalized daily food insights', style: TextStyle(fontSize: 10, color: _muted)),
        ])),
        if (_insight != null)
          IconButton(tooltip: 'Refresh analysis', onPressed: _loading ? null : _analyze, icon: const Icon(Icons.refresh_rounded, color: _muted, size: 19)),
      ]),
      const SizedBox(height: 11),
      if (_insight == null && _error == null)
        Text(widget.meals.isEmpty ? 'Log a meal to receive nutrition feedback.' : 'Get feedback on your logged meals, calories and macros.', style: const TextStyle(fontSize: 11, color: _muted)),
      if (_loading) ...[
        const SizedBox(height: 8),
        const Row(children: [SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: _lime)), SizedBox(width: 9), Text('Reviewing your daily nutrition...', style: TextStyle(fontSize: 11, color: _muted))]),
      ],
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFFF9B8F)))),
      if (_insight case final insight?) ...[
        Text(insight.summary, style: const TextStyle(fontSize: 12, height: 1.5, color: _ink)),
        if (insight.strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('WHAT YOU DID WELL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _lime, letterSpacing: 0.7)),
          const SizedBox(height: 5),
          ...insight.strengths.map((item) => _InsightBullet(text: item, color: _lime)),
        ],
        if (insight.suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('SUGGESTIONS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFFFC66D), letterSpacing: 0.7)),
          const SizedBox(height: 5),
          ...insight.suggestions.map((item) => _InsightBullet(text: item, color: const Color(0xFFFFC66D))),
        ],
        const SizedBox(height: 10),
        Text(insight.disclaimer, style: const TextStyle(fontSize: 9, color: _muted)),
      ],
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 42, child: OutlinedButton.icon(
        onPressed: _loading || widget.meals.isEmpty ? null : _analyze,
        icon: _loading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded, size: 16),
        label: Text(_loading ? 'Analyzing...' : _insight == null ? 'Analyze my nutrition' : 'Analyze again'),
        style: OutlinedButton.styleFrom(foregroundColor: _lime, side: const BorderSide(color: Color(0xFF526B3B)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
      )),
    ]),
  );
}

class _InsightBullet extends StatelessWidget {
  const _InsightBullet({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 6, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11, height: 1.4, color: _ink))),
    ]),
  );
}

class _MacroSummary extends StatelessWidget {
  const _MacroSummary({required this.protein, required this.carbs, required this.fat});
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(17)),
    child: Row(children: [
      const Text('Macros', style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w700)),
      const Spacer(),
      _MacroValue(label: 'Protein', value: protein, color: const Color(0xFF9BFF3D)),
      const SizedBox(width: 13),
      _MacroValue(label: 'Carbs', value: carbs, color: const Color(0xFFFFC66D)),
      const SizedBox(width: 13),
      _MacroValue(label: 'Fat', value: fat, color: const Color(0xFF7BC8FF)),
    ]),
  );
}

class _MacroValue extends StatelessWidget {
  const _MacroValue({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text('${value.toStringAsFixed(0)}g', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: _muted)),
  ]);
}

class _MealCategory extends StatelessWidget {
  const _MealCategory({required this.icon, required this.title, required this.calories, required this.color});
  final IconData icon; final String title; final int calories; final Color color;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(18)), child: Column(children: [
    Container(width: 34, height: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: _ink)),
    const SizedBox(height: 7), Text(calories.toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink)), Text(title, style: const TextStyle(fontSize: 10, color: _muted)),
  ]));
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final Meal meal;
  Future<void> _delete(BuildContext context) async {
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Delete meal?'), content: Text('Delete "' + meal.foodName + '" permanently?'), actions: [
      TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Delete')),
    ]));
    if (yes != true || !context.mounted) return;
    try {
      await NutritionService.instance.deleteMeal(meal.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal deleted.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete meal. Please try again.')));
    }
  }
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(19)), child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF202922), borderRadius: BorderRadius.circular(16)), child: Icon(_mealIcon(meal.category), color: _ink, size: 23)),
    const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(meal.foodName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 13)),
      const SizedBox(height: 4), Text(meal.category, style: const TextStyle(fontSize: 11, color: _muted)),
      if (meal.proteinGrams > 0 || meal.carbsGrams > 0 || meal.fatGrams > 0) ...[
        const SizedBox(height: 4),
        Text('P ${meal.proteinGrams.toStringAsFixed(0)}g  C ${meal.carbsGrams.toStringAsFixed(0)}g  F ${meal.fatGrams.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 10, color: _muted)),
      ],
      const SizedBox(height: 4), Text(MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(meal.date)), style: const TextStyle(fontSize: 10, color: _muted)),
    ])),
    const SizedBox(width: 8),
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(meal.calories.toString() + ' kcal', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _ink)),
      PopupMenuButton<String>(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 140), iconSize: 20, icon: const Icon(Icons.more_horiz_rounded, color: _muted), onSelected: (v) {
        if (v == 'edit') Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditMealScreen(meal: meal)));
        if (v == 'delete') _delete(context);
      }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit meal')), PopupMenuItem(value: 'delete', child: Text('Delete meal'))]),
    ]),
  ]));
}

IconData _mealIcon(String category) => switch (category) {
  'Breakfast' => Icons.wb_sunny_outlined,
  'Lunch' => Icons.lunch_dining_outlined,
  'Dinner' => Icons.nights_stay_outlined,
  _ => Icons.cookie_outlined,
};
