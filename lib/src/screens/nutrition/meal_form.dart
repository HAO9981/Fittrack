import 'package:flutter/material.dart';

import '../../models/meal.dart';

class MealForm extends StatefulWidget {
  const MealForm({
    super.key,
    this.meal,
    required this.submitLabel,
    required this.onSubmit,
  });

  final Meal? meal;
  final String submitLabel;
  final Future<void> Function(Meal meal) onSubmit;

  @override
  State<MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<MealForm> {
  static const _categories = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _foodNameController;
  late final TextEditingController _caloriesController;
  String? _category;
  late DateTime _date;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _foodNameController = TextEditingController(text: meal?.foodName ?? '');
    _caloriesController = TextEditingController(text: meal?.calories.toString() ?? '');
    _category = meal?.category;
    _date = DateUtils.dateOnly(meal?.date ?? DateTime.now());
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selectedDate != null && mounted) setState(() => _date = selectedDate);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final meal = Meal(
      id: widget.meal?.id ?? '',
      foodName: _foodNameController.text.trim(),
      category: _category!,
      calories: int.parse(_caloriesController.text),
      date: _date,
      createdAt: widget.meal?.createdAt,
    );

    try {
      await widget.onSubmit(meal);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is StateError ? error.message.toString() : 'Unable to save meal. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Log your meal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFF4F7F1))),
                const SizedBox(height: 5),
                const Text('Keep track of what you eat each day.', style: TextStyle(fontSize: 13, color: Color(0xFF9AA69C))),
                const SizedBox(height: 22),
                const Text('Food name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _foodNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Chicken rice', prefixIcon: Icon(Icons.restaurant_outlined)),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a food name.' : null,
                ),
                const SizedBox(height: 17),
                const Text('Meal type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined), hintText: 'Choose a meal type'),
                  items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) => value == null ? 'Select a meal category.' : null,
                ),
                const SizedBox(height: 17),
                const Text('Calories (kcal)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 450', prefixIcon: Icon(Icons.local_fire_department_outlined)),
                  validator: (value) {
                    final calories = int.tryParse(value ?? '');
                    return calories == null || calories <= 0 ? 'Enter a positive calorie value.' : null;
                  },
                ),
                const SizedBox(height: 17),
                const Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
                    decoration: BoxDecoration(color: const Color(0xFF101613), border: Border.all(color: const Color(0xFF27332B)), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_outlined, color: Color(0xFF9AA69C)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(MaterialLocalizations.of(context).formatMediumDate(_date), style: const TextStyle(fontSize: 14))),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA69C)),
                    ]),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(height: 52, child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : widget.submitLabel),
                )),
                const SizedBox(height: 8),
                SizedBox(height: 48, child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF27332B)), backgroundColor: const Color(0xFF141B17), foregroundColor: const Color(0xFFF4F7F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Cancel'),
                )),
              ],
            ),
          ),
        ),
      );
}
