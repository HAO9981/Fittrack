import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/meal.dart';
import '../../services/food_ai_service.dart';

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
  static const _lime = Color(0xFF9BFF3D);
  static const _muted = Color(0xFF9AA69C);

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _foodNameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _portionController;
  String? _category;
  late DateTime _date;
  Uint8List? _imageBytes;
  String? _imageMimeType;
  String? _aiNote;
  bool _isAnalyzing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _foodNameController = TextEditingController(text: meal?.foodName ?? '');
    _caloriesController = TextEditingController(text: meal?.calories.toString() ?? '');
    _proteinController = TextEditingController(text: _formatMacro(meal?.proteinGrams));
    _carbsController = TextEditingController(text: _formatMacro(meal?.carbsGrams));
    _fatController = TextEditingController(text: _formatMacro(meal?.fatGrams));
    _portionController = TextEditingController(text: meal?.portion ?? '');
    _category = meal?.category;
    _date = DateUtils.dateOnly(meal?.date ?? DateTime.now());
    _aiNote = meal?.nutritionNote;
  }

  String _formatMacro(double? value) =>
      value == null || value == 0 ? '' : value.toStringAsFixed(1);

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  Future<void> _pickFoodImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = image.name.toLowerCase().split('.').last;
      final mimeType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageMimeType = mimeType;
        _aiNote = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to select this image. Please try again.')),
      );
    }
  }

  Future<void> _analyzeFood() async {
    final bytes = _imageBytes;
    final mimeType = _imageMimeType;
    if (bytes == null || mimeType == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);
    try {
      final result = await FoodAiService.instance.analyzeImage(
        imageBytes: bytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      setState(() {
        _foodNameController.text = result.foodName;
        _caloriesController.text = result.calories.toString();
        _proteinController.text = result.proteinGrams.toStringAsFixed(1);
        _carbsController.text = result.carbsGrams.toStringAsFixed(1);
        _fatController.text = result.fatGrams.toStringAsFixed(1);
        _portionController.text = result.portion;
        _aiNote = result.notes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food analysis completed. Please review the estimates.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? 'The AI response could not be understood. Please try another photo.'
          : 'Food analysis failed. Check your connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
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
    if (_category == null) return;

    setState(() => _isSaving = true);
    final meal = Meal(
      id: widget.meal?.id ?? '',
      foodName: _foodNameController.text.trim(),
      category: _category!,
      calories: int.parse(_caloriesController.text),
      date: _date,
      proteinGrams: double.tryParse(_proteinController.text) ?? 0,
      carbsGrams: double.tryParse(_carbsController.text) ?? 0,
      fatGrams: double.tryParse(_fatController.text) ?? 0,
      portion: _portionController.text.trim().isEmpty ? null : _portionController.text.trim(),
      nutritionNote: _aiNote,
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

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool required = false,
  }) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: hint),
            validator: (value) {
              if (required && (int.tryParse(value ?? '') == null || int.parse(value!) <= 0)) {
                return 'Enter a positive calorie value.';
              }
              final number = double.tryParse(value ?? '');
              if (!required && value != null && value.trim().isNotEmpty &&
                  (number == null || number < 0)) {
                return 'Enter a valid non-negative number.';
              }
              return null;
            },
          ),
        ],
      );

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
                const Text('Scan a food photo or enter nutrition details manually.', style: TextStyle(fontSize: 13, color: _muted)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_imageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.memory(_imageBytes!, height: 190, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 10),
                    ] else
                      Container(
                        height: 110,
                        decoration: BoxDecoration(color: const Color(0xFF202922), borderRadius: BorderRadius.circular(13)),
                        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.document_scanner_outlined, size: 32, color: _lime),
                          SizedBox(height: 7),
                          Text('Add a photo of your food', style: TextStyle(color: _muted, fontSize: 12)),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _isAnalyzing ? null : () => _pickFoodImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take photo'),
                      )),
                      const SizedBox(width: 9),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _isAnalyzing ? null : () => _pickFoodImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      )),
                    ]),
                    const SizedBox(height: 4),
                    SizedBox(height: 46, child: ElevatedButton.icon(
                      onPressed: _imageBytes == null || _isAnalyzing ? null : _analyzeFood,
                      icon: _isAnalyzing
                          ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(_isAnalyzing ? 'Analyzing food...' : 'Analyze with FitTrack AI'),
                    )),
                    const SizedBox(height: 7),
                    const Text('AI values are estimates. Review them before saving.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: _muted)),
                  ]),
                ),
                const SizedBox(height: 20),
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
                _numberField(label: 'Calories (kcal)', controller: _caloriesController, hint: 'e.g. 450', required: true),
                const SizedBox(height: 17),
                const Text('Portion size', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                TextFormField(controller: _portionController, decoration: const InputDecoration(hintText: 'e.g. 1 medium bowl')),
                const SizedBox(height: 17),
                const Text('Macronutrients (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Row(children: [
                  Expanded(child: _numberField(label: 'Protein (g)', controller: _proteinController, hint: '0')),
                  const SizedBox(width: 9),
                  Expanded(child: _numberField(label: 'Carbs (g)', controller: _carbsController, hint: '0')),
                  const SizedBox(width: 9),
                  Expanded(child: _numberField(label: 'Fat (g)', controller: _fatController, hint: '0')),
                ]),
                if (_aiNote != null && _aiNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFF202922), borderRadius: BorderRadius.circular(12)), child: Text('AI note: $_aiNote', style: const TextStyle(fontSize: 11, color: _muted))),
                ],
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
                      const Icon(Icons.calendar_month_outlined, color: _muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(MaterialLocalizations.of(context).formatMediumDate(_date), style: const TextStyle(fontSize: 14))),
                      const Icon(Icons.chevron_right_rounded, color: _muted),
                    ]),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(height: 52, child: ElevatedButton(
                  onPressed: _isSaving || _isAnalyzing ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : widget.submitLabel),
                )),
                const SizedBox(height: 8),
                SizedBox(height: 48, child: OutlinedButton(
                  onPressed: _isSaving || _isAnalyzing ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF27332B)), backgroundColor: const Color(0xFF141B17), foregroundColor: const Color(0xFFF4F7F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Cancel'),
                )),
              ],
            ),
          ),
        ),
      );
}
