import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../services/auth_service.dart';
import '../../services/nutrition_service.dart';
import '../../widgets/app_empty_state.dart';
import 'add_meal_screen.dart';
import 'edit_meal_screen.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  late Stream<List<Meal>> _mealsStream;

  @override
  void initState() {
    super.initState();
    _mealsStream = NutritionService.instance.getMealsByDate(_selectedDate);
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selectedDate != null && mounted) {
      final date = DateUtils.dateOnly(selectedDate);
      setState(() {
        _selectedDate = date;
        // Recreate the query only when the user actually changes the date.
        _mealsStream = NutritionService.instance.getMealsByDate(date);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Nutrition'),
          actions: [
            IconButton(
              tooltip: 'Choose date',
              icon: const Icon(Icons.calendar_today),
              onPressed: _selectDate,
            ),
          ],
        ),
        body: StreamBuilder<List<Meal>>(
          stream: _mealsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _NutritionMessage(
                icon: Icons.error_outline,
                message: snapshot.error is StateError
                    ? 'Please sign in to view your nutrition records.'
                    : 'Unable to load nutrition records. Please try again.',
              );
            }

            final meals = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _NutritionSummary(meals: meals, selectedDate: _selectedDate, onSelectDate: _selectDate),
                const SizedBox(height: 24),
                Text(
                  DateUtils.isSameDay(_selectedDate, DateTime.now())
                      ? "Today's Meals"
                      : 'Meals for ${MaterialLocalizations.of(context).formatMediumDate(_selectedDate)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (meals.isEmpty)
                  const AppEmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'No meals recorded',
                    message: 'Add a meal to start tracking calories for this date.',
                  )
                else
                  ...meals.map(
                    (meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MealCard(meal: meal),
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (FirebaseAuthService.instance.currentUser == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to add a meal.')));
              return;
            }
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMealScreen()));
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Meal'),
        ),
      );
}

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({
    required this.meals,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final List<Meal> meals;
  final DateTime selectedDate;
  final Future<void> Function() onSelectDate;

  @override
  Widget build(BuildContext context) {
    final caloriesByCategory = {
      for (final category in ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
        category: meals.where((meal) => meal.category == category).fold(0, (total, meal) => total + meal.calories),
    };
    final totalCalories = meals.fold(0, (total, meal) => total + meal.calories);
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isToday ? "Today's Nutrition" : 'Nutrition Summary', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onSelectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(MaterialLocalizations.of(context).formatMediumDate(selectedDate)),
            ),
            const SizedBox(height: 12),
            Text('Total Calories', style: Theme.of(context).textTheme.titleMedium),
            Text('$totalCalories kcal', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: caloriesByCategory.entries
                  .map((entry) => _CategoryCalories(category: entry.key, calories: entry.value))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCalories extends StatelessWidget {
  const _CategoryCalories({required this.category, required this.calories});

  final String category;
  final int calories;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$category: $calories kcal'),
      );
}

class _NutritionMessage extends StatelessWidget {
  const _NutritionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      );
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final Meal meal;

  Future<void> _deleteMeal(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Delete "${meal.foodName}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;

    try {
      await NutritionService.instance.deleteMeal(meal.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal deleted.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete meal. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(_mealIcon(meal.category), color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          title: Text(meal.foodName, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${meal.category} - ${meal.calories} kcal\n${MaterialLocalizations.of(context).formatMediumDate(meal.date)}',
            ),
          ),
          isThreeLine: true,
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit meal',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EditMealScreen(meal: meal)),
                ),
              ),
              IconButton(
                tooltip: 'Delete meal',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteMeal(context),
              ),
            ],
          ),
        ),
      );
}

IconData _mealIcon(String category) => switch (category) {
      'Breakfast' => Icons.wb_sunny_outlined,
      'Lunch' => Icons.lunch_dining_outlined,
      'Dinner' => Icons.nights_stay_outlined,
      _ => Icons.cookie_outlined,
    };
