import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../services/nutrition_service.dart';
import 'edit_meal_screen.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _panel = Color(0xFF141B17);
const _background = Color(0xFF080D0B);

class FoodHistoryScreen extends StatefulWidget {
  const FoodHistoryScreen({super.key});

  @override
  State<FoodHistoryScreen> createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends State<FoodHistoryScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';
  DateTime? _selectedDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = DateUtils.dateOnly(picked));
    }
  }

  List<Meal> _filter(List<Meal> meals) {
    final query = _searchController.text.trim().toLowerCase();
    return meals.where((meal) {
      final matchesQuery = query.isEmpty ||
          meal.foodName.toLowerCase().contains(query) ||
          (meal.nutritionNote ?? '').toLowerCase().contains(query) ||
          (meal.portion ?? '').toLowerCase().contains(query);
      final matchesCategory = _category == 'All' || meal.category == _category;
      final matchesDate = _selectedDate == null ||
          DateUtils.isSameDay(meal.date, _selectedDate);
      return matchesQuery && matchesCategory && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      foregroundColor: _ink,
      title: const Text('Food History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
    ),
    body: StreamBuilder<List<Meal>>(
      stream: NutritionService.instance.getMeals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _lime));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load food history.', style: TextStyle(color: _muted)));
        }
        final allMeals = snapshot.data ?? <Meal>[];
        final meals = _filter(allMeals);
        final totalCalories = meals.fold<int>(0, (sum, meal) => sum + meal.calories);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Column(children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: _ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search food name or notes...',
                  hintStyle: const TextStyle(color: _muted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded, color: _muted),
                        ),
                  filled: true,
                  fillColor: _panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(13)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _category,
                        isExpanded: true,
                        dropdownColor: _panel,
                        style: const TextStyle(color: _ink, fontSize: 12),
                        items: const ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack']
                            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setState(() => _category = value ?? 'All'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(_selectedDate == null
                      ? 'Date'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _lime,
                    side: const BorderSide(color: Color(0xFF526B3B)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: () => setState(() => _selectedDate = null),
                    icon: const Icon(Icons.filter_alt_off_rounded, color: _muted),
                  ),
              ]),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
                child: Row(children: [
                  Expanded(child: _summary('Matching records', meals.length.toString())),
                  Expanded(child: _summary('Calories shown', '$totalCalories kcal')),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: meals.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.manage_search_rounded, color: _muted, size: 42),
                        const SizedBox(height: 12),
                        const Text('No matching meals', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        const Text('Try another keyword or clear your filters.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 11)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _category = 'All';
                            _selectedDate = null;
                          }),
                          child: const Text('Clear all filters', style: TextStyle(color: _lime)),
                        ),
                      ]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    itemCount: meals.length,
                    itemBuilder: (context, index) => _HistoryMealCard(
                      meal: meals[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EditMealScreen(meal: meals[index])),
                      ),
                    ),
                  ),
          ),
        ]);
      },
    ),
  );

  Widget _summary(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
  ]);
}

class _HistoryMealCard extends StatelessWidget {
  const _HistoryMealCard({required this.meal, required this.onTap});
  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(13)),
        child: const Icon(Icons.restaurant_rounded, color: _lime, size: 20),
      ),
      title: Text(meal.foodName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${meal.category} · ${meal.date.day}/${meal.date.month}/${meal.date.year}'
          '${meal.portion == null || meal.portion!.isEmpty ? '' : ' · ${meal.portion}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
      ),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${meal.calories}', style: const TextStyle(color: _lime, fontSize: 14, fontWeight: FontWeight.w800)),
        const Text('kcal', style: TextStyle(color: _muted, fontSize: 9)),
      ]),
    ),
  );
}
