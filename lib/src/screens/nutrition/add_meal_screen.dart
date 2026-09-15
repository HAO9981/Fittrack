import 'package:flutter/material.dart';

import '../../models/meal.dart';
import '../../services/nutrition_service.dart';
import 'meal_form.dart';

class AddMealScreen extends StatelessWidget {
  const AddMealScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add Meal')),
        body: SafeArea(
          child: MealForm(
            submitLabel: 'Save meal',
            onSubmit: (Meal meal) => NutritionService.instance.addMeal(meal),
          ),
        ),
      );
}
