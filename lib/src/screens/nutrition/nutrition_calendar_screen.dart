import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../services/nutrition_service.dart';
import 'edit_meal_screen.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _panel = Color(0xFF141B17);
const _background = Color(0xFF080D0B);

class NutritionCalendarScreen extends StatefulWidget {
  const NutritionCalendarScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<NutritionCalendarScreen> createState() => _NutritionCalendarScreenState();
}

class _NutritionCalendarScreenState extends State<NutritionCalendarScreen> {
  late DateTime _month;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final initial = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    _month = DateTime(initial.year, initial.month);
    _selectedDate = initial;
  }

  void _changeMonth(int amount) {
    setState(() => _month = DateTime(_month.year, _month.month + amount));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      foregroundColor: _ink,
      title: const Text('Nutrition Calendar', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _selectedDate = DateUtils.dateOnly(DateTime.now());
            _month = DateTime(_selectedDate.year, _selectedDate.month);
          }),
          child: const Text('Today', style: TextStyle(color: _lime)),
        ),
      ],
    ),
    body: StreamBuilder<List<Meal>>(
      stream: NutritionService.instance.getMeals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _lime));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load nutrition calendar.', style: TextStyle(color: _muted)));
        }
        final meals = snapshot.data ?? <Meal>[];
        final dailyMeals = meals.where((meal) => DateUtils.isSameDay(meal.date, _selectedDate)).toList();
        final dailyCalories = dailyMeals.fold<int>(0, (sum, meal) => sum + meal.calories);
        final dailyProtein = dailyMeals.fold<double>(0, (sum, meal) => sum + meal.proteinGrams);
        final dailyCarbs = dailyMeals.fold<double>(0, (sum, meal) => sum + meal.carbsGrams);
        final dailyFat = dailyMeals.fold<double>(0, (sum, meal) => sum + meal.fatGrams);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _buildCalendar(meals),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  MaterialLocalizations.of(context).formatMediumDate(_selectedDate),
                  style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _metric('Calories', '$dailyCalories', 'kcal'),
                  _metric('Protein', dailyProtein.toStringAsFixed(1), 'g'),
                  _metric('Carbs', dailyCarbs.toStringAsFixed(1), 'g'),
                  _metric('Fat', dailyFat.toStringAsFixed(1), 'g'),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(_selectedDate),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('View this day in Nutrition'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _lime,
                      foregroundColor: const Color(0xFF101610),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Meals on selected day', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
              Text('${dailyMeals.length} items', style: const TextStyle(color: _muted, fontSize: 11)),
            ]),
            const SizedBox(height: 9),
            if (dailyMeals.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
                child: const Text('No meal records for this date.', style: TextStyle(color: _muted, fontSize: 12)),
              )
            else
              ...dailyMeals.map((meal) => _CalendarMealTile(
                meal: meal,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EditMealScreen(meal: meal)),
                ),
              )),
          ],
        );
      },
    ),
  );

  Widget _buildCalendar(List<Meal> meals) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = firstDay.weekday - 1;
    final cellCount = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final loggedDays = <String>{};
    for (final meal in meals) {
      if (meal.date.year == _month.year && meal.date.month == _month.month) {
        loggedDays.add('${meal.date.year}-${meal.date.month}-${meal.date.day}');
      }
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded, color: _ink)),
          Expanded(
            child: Text(
              '${_monthName(_month.month)} ${_month.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _month.year == DateTime.now().year && _month.month == DateTime.now().month
                ? null
                : () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right_rounded, color: _ink),
          ),
        ]),
        const SizedBox(height: 8),
        Row(
          children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((day) => Expanded(child: Center(child: Text(day, style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700)))))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 3,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - offset + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();
            final date = DateTime(_month.year, _month.month, dayNumber);
            final selected = DateUtils.isSameDay(date, _selectedDate);
            final today = DateUtils.isSameDay(date, DateTime.now());
            final hasMeals = loggedDays.contains('${date.year}-${date.month}-${date.day}');
            return InkWell(
              onTap: () => setState(() => _selectedDate = date),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? _lime : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: today && !selected ? Border.all(color: _lime, width: 1) : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: selected ? const Color(0xFF101610) : _ink,
                      fontSize: 12,
                      fontWeight: selected || today ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasMeals ? (selected ? const Color(0xFF101610) : _lime) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        const Row(children: [
          Icon(Icons.circle, size: 7, color: _lime),
          SizedBox(width: 6),
          Text('Days with meal records', style: TextStyle(color: _muted, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value, String unit) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
      Text(unit, style: const TextStyle(color: _muted, fontSize: 9)),
    ]),
  );

  String _monthName(int month) => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][month - 1];
}

class _CalendarMealTile extends StatelessWidget {
  const _CalendarMealTile({required this.meal, required this.onTap});
  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
    child: ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF25351D),
        child: Icon(Icons.restaurant_rounded, color: _lime, size: 18),
      ),
      title: Text(meal.foodName, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text(meal.category, style: const TextStyle(color: _muted, fontSize: 10)),
      trailing: Text('${meal.calories} kcal', style: const TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w800)),
    ),
  );
}
