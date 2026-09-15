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
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _foodNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Food name'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a food name.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Meal category'),
                  items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) => value == null ? 'Select a meal category.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                  validator: (value) {
                    final calories = int.tryParse(value ?? '');
                    return calories == null || calories <= 0 ? 'Enter a positive calorie value.' : null;
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Date: ${MaterialLocalizations.of(context).formatMediumDate(_date)}'),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : widget.submitLabel),
                ),
              ],
            ),
          ),
        ),
      );
}
