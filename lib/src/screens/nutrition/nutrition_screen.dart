import 'package:flutter/material.dart';
import '../../models/meal.dart';
import '../../services/auth_service.dart';
import '../../services/nutrition_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_meal_screen.dart';
import 'edit_meal_screen.dart';

const _lime = Color(0xFF84E221);
const _ink = Color(0xFF232824);
const _muted = Color(0xFF858C83);
const _bg = Color(0xFFF6F7F4);

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
          Row(children: [const Expanded(child: Text('Nutrition', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink))), IconButton(onPressed: _chooseDate, tooltip: 'Choose date', icon: const Icon(Icons.calendar_month_rounded, color: _ink))]),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [
            IconButton(onPressed: () => _moveDate(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: InkWell(onTap: _chooseDate, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(today ? 'Today' : MaterialLocalizations.of(context).formatMediumDate(_date), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink))))),
            IconButton(onPressed: today ? null : () => _moveDate(1), icon: const Icon(Icons.chevron_right_rounded)),
          ])),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: Row(children: [
            SizedBox(width: 124, height: 124, child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(value: (total / 2000).clamp(0.0, 1.0), strokeWidth: 10, backgroundColor: const Color(0xFFE7EAE4), valueColor: const AlwaysStoppedAnimation<Color>(_lime))),
              Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFA52D), size: 20), const SizedBox(height: 3), Text(total.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)), const Text('of 2,000 kcal', style: TextStyle(fontSize: 10, color: _muted))]),
            ])),
            const SizedBox(width: 17),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Daily intake', style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 5),
              Text((2000 - total).clamp(0, 2000).toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ink)),
              const Text('kcal remaining', style: TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 9),
              Text(total >= 2000 ? 'Daily goal reached' : 'Keep logging meals', style: const TextStyle(fontSize: 11, color: _muted)),
            ])),
          ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _MealCategory(icon: Icons.wb_sunny_outlined, title: 'Breakfast', calories: _categoryTotal(meals, 'Breakfast'), color: const Color(0xFFFFF0D9))),
            const SizedBox(width: 8),
            Expanded(child: _MealCategory(icon: Icons.lunch_dining_outlined, title: 'Lunch', calories: _categoryTotal(meals, 'Lunch'), color: const Color(0xFFEAF6D9))),
            const SizedBox(width: 8),
            Expanded(child: _MealCategory(icon: Icons.nights_stay_outlined, title: 'Dinner', calories: _categoryTotal(meals, 'Dinner'), color: const Color(0xFFE7F1F0))),
          ]),
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

class _MealCategory extends StatelessWidget {
  const _MealCategory({required this.icon, required this.title, required this.calories, required this.color});
  final IconData icon; final String title; final int calories; final Color color;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [
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
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19)), child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF0F3EC), borderRadius: BorderRadius.circular(16)), child: Icon(_mealIcon(meal.category), color: _ink, size: 23)),
    const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(meal.foodName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 13)),
      const SizedBox(height: 4), Text(meal.category, style: const TextStyle(fontSize: 11, color: _muted)),
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
