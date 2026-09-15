import 'package:flutter/material.dart';

import '../../models/workout.dart';

class WorkoutForm extends StatefulWidget {
  const WorkoutForm({
    super.key,
    this.workout,
    required this.submitLabel,
    required this.onSubmit,
  });

  final Workout? workout;
  final String submitLabel;
  final Future<void> Function(Workout workout) onSubmit;

  @override
  State<WorkoutForm> createState() => _WorkoutFormState();
}

class _WorkoutFormState extends State<WorkoutForm> {
  static const _categories = ['Strength', 'Cardio', 'Flexibility', 'HIIT', 'Other'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  String? _category;
  late DateTime _date;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final workout = widget.workout;
    _nameController = TextEditingController(text: workout?.name ?? '');
    _durationController = TextEditingController(text: workout?.duration.toString() ?? '');
    _category = workout?.category;
    _date = workout?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
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
    final workout = Workout(
      id: widget.workout?.id ?? '',
      name: _nameController.text.trim(),
      category: _category!,
      duration: int.parse(_durationController.text),
      date: _date,
      createdAt: widget.workout?.createdAt,
    );

    try {
      await widget.onSubmit(workout);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is StateError ? error.message.toString() : 'Unable to save workout. Please try again.')),
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
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Workout name'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a workout name.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) => value == null ? 'Select a category.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                  validator: (value) {
                    final duration = int.tryParse(value ?? '');
                    return duration == null || duration <= 0 ? 'Enter a positive duration.' : null;
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
