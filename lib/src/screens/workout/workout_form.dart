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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Build your routine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF232824))),
                const SizedBox(height: 5),
                const Text('Record the details of your workout.', style: TextStyle(fontSize: 13, color: Color(0xFF858C83))),
                const SizedBox(height: 22),
                const Text('Exercise name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Running', prefixIcon: Icon(Icons.fitness_center_rounded)),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a workout name.' : null,
                ),
                const SizedBox(height: 17),
                const Text('Workout type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined), hintText: 'Choose a category'),
                  items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) => value == null ? 'Select a category.' : null,
                ),
                const SizedBox(height: 17),
                const Text('Duration (minutes)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '30', prefixIcon: Icon(Icons.schedule_rounded)),
                  validator: (value) {
                    final duration = int.tryParse(value ?? '');
                    return duration == null || duration <= 0 ? 'Enter a positive duration.' : null;
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
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE8EBE5)), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_outlined, color: Color(0xFF858C83)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(MaterialLocalizations.of(context).formatMediumDate(_date), style: const TextStyle(fontSize: 14))),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF858C83)),
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
                  style: OutlinedButton.styleFrom(side: BorderSide.none, backgroundColor: const Color(0xFFEDEFEA), foregroundColor: const Color(0xFF232824), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Cancel'),
                )),
              ],
            ),
          ),
        ),
      );
}
