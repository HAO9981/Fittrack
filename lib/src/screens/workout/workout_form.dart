import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/workout.dart';
import '../../services/workout_category_service.dart';
import '../../services/workout_service.dart';

class WorkoutForm extends StatefulWidget {
  const WorkoutForm({
    super.key,
    this.workout,
    this.initialName,
    this.initialCategory,
    this.initialSets,
    this.initialReps,
    this.initialDuration,
    this.initialDurationUnit = 'minutes',
    required this.submitLabel,
    required this.onSubmit,
  });

  final Workout? workout;
  final String? initialName;
  final String? initialCategory;
  final int? initialSets;
  final int? initialReps;
  final int? initialDuration;
  final String initialDurationUnit;
  final String submitLabel;
  final Future<void> Function(Workout workout) onSubmit;

  @override
  State<WorkoutForm> createState() => _WorkoutFormState();
}

class _OptionalNumberField extends StatelessWidget {
  const _OptionalNumberField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, hintText: hint),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return null;
      final number = int.tryParse(value.trim());
      return number == null || number <= 0 ? 'Enter a positive number.' : null;
    },
  );
}

class _WorkoutFormState extends State<WorkoutForm> {
  late final Stream<WorkoutCategorySettings> _categorySettingsStream;
  late final Stream<List<Workout>> _workoutsStream;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  String? _category;
  late String _durationUnit;
  late DateTime _date;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    try {
      _categorySettingsStream = WorkoutCategoryService.instance.watch();
      _workoutsStream = WorkoutService.instance.getWorkouts();
    } on FirebaseException {
      // Keep the form usable in isolated widget tests before Firebase setup.
      _categorySettingsStream = Stream.value(const WorkoutCategorySettings());
      _workoutsStream = Stream.value(const <Workout>[]);
    }
    final workout = widget.workout;
    _nameController = TextEditingController(
      text: workout?.name ?? widget.initialName ?? '',
    );
    _durationController = TextEditingController(
      text:
          workout?.duration.toString() ??
          widget.initialDuration?.toString() ??
          '',
    );
    _setsController = TextEditingController(
      text: workout?.sets?.toString() ?? widget.initialSets?.toString() ?? '',
    );
    _repsController = TextEditingController(
      text: workout?.reps?.toString() ?? widget.initialReps?.toString() ?? '',
    );
    _category = workout?.category ?? widget.initialCategory;
    _durationUnit = workout?.durationUnit ?? widget.initialDurationUnit;
    _date = workout?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _setsController.dispose();
    _repsController.dispose();
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
      durationUnit: _durationUnit,
      sets: int.tryParse(_setsController.text),
      reps: int.tryParse(_repsController.text),
      date: _date,
      createdAt: widget.workout?.createdAt,
    );

    try {
      await widget.onSubmit(workout);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Unable to save workout. Please try again.',
            ),
          ),
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
            const Text(
              'Build your routine',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF4F7F1),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Record the details of your workout.',
              style: TextStyle(fontSize: 13, color: Color(0xFF9AA69C)),
            ),
            const SizedBox(height: 22),
            const Text(
              'Exercise name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Running',
                prefixIcon: Icon(Icons.fitness_center_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a workout name.'
                  : null,
            ),
            const SizedBox(height: 17),
            const Text(
              'Workout type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            StreamBuilder<WorkoutCategorySettings>(
              stream: _categorySettingsStream,
              builder: (context, snapshot) {
                return StreamBuilder<List<Workout>>(
                  stream: _workoutsStream,
                  builder: (context, workoutsSnapshot) {
                    final categories = <String>{
                      ...WorkoutCategoryService.systemCategories,
                      ...?snapshot.data?.custom,
                      ...?workoutsSnapshot.data?.map(
                        (workout) => workout.category,
                      ),
                      ...?(_category == null ? null : [_category!]),
                    }.toList();
                    return DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                        hintText: 'Choose a category',
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _category = value),
                      validator: (value) =>
                          value == null ? 'Select a category.' : null,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Duration',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 122,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _durationUnit,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'minutes',
                        child: Text('Minutes'),
                      ),
                      DropdownMenuItem(
                        value: 'seconds',
                        child: Text('Seconds'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _durationUnit) return;
                      final amount = int.tryParse(_durationController.text);
                      if (amount != null) {
                        _durationController.text = _durationUnit == 'minutes'
                            ? (amount * 60).toString()
                            : (amount / 60).ceil().toString();
                      }
                      setState(() => _durationUnit = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: _durationUnit == 'seconds' ? '60' : '30',
                prefixIcon: const Icon(Icons.schedule_rounded),
              ),
              validator: (value) {
                final duration = int.tryParse(value ?? '');
                return duration == null || duration <= 0
                    ? 'Enter a positive duration.'
                    : null;
              },
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: _OptionalNumberField(
                    controller: _setsController,
                    label: 'Sets',
                    hint: 'e.g. 3',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OptionalNumberField(
                    controller: _repsController,
                    label: 'Reps',
                    hint: 'e.g. 12',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            const Text(
              'Date',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 17,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF101613),
                  border: Border.all(color: const Color(0xFF27332B)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: Color(0xFF9AA69C),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(_date),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9AA69C),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Saving...' : widget.submitLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF27332B)),
                  backgroundColor: const Color(0xFF141B17),
                  foregroundColor: const Color(0xFFF4F7F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
