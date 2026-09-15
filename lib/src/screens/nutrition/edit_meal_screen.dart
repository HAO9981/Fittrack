import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../services/nutrition_service.dart';
import 'meal_form.dart';

class EditMealScreen extends StatelessWidget {
  const EditMealScreen({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit Meal')),
        body: SafeArea(
          child: MealForm(
            meal: meal,
            submitLabel: 'Update meal',
            onSubmit: (updatedMeal) => NutritionService.instance.updateMeal(updatedMeal),
          ),
        ),
      );
}
