import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class NutritionGoals {
  const NutritionGoals({
    this.calories = 2000,
    this.proteinGrams = 120,
    this.carbsGrams = 250,
    this.fatGrams = 65,
  });

  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  factory NutritionGoals.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NutritionGoals();
    return NutritionGoals(
      calories: (data['calories'] as num?)?.toInt() ?? 2000,
      proteinGrams: (data['proteinGrams'] as num?)?.toDouble() ?? 120,
      carbsGrams: (data['carbsGrams'] as num?)?.toDouble() ?? 250,
      fatGrams: (data['fatGrams'] as num?)?.toDouble() ?? 65,
    );
  }

  Map<String, dynamic> toMap() => {
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class NutritionGoalService {
  NutritionGoalService._();
  static final NutritionGoalService instance = NutritionGoalService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _document {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) throw StateError('Please sign in to manage nutrition goals.');
    return _firestore.collection('users').doc(user.uid)
        .collection('settings').doc('nutritionGoals');
  }

  Stream<NutritionGoals> watchGoals() {
    try {
      return _document.snapshots().map((snapshot) =>
          NutritionGoals.fromMap(snapshot.data()));
    } on StateError catch (error) {
      return Stream<NutritionGoals>.error(error);
    }
  }

  Future<void> saveGoals(NutritionGoals goals) async {
    if (goals.calories < 500 || goals.calories > 10000 ||
        goals.proteinGrams < 0 || goals.proteinGrams > 500 ||
        goals.carbsGrams < 0 || goals.carbsGrams > 1000 ||
        goals.fatGrams < 0 || goals.fatGrams > 500) {
      throw ArgumentError('Please enter nutrition goals within the allowed ranges.');
    }
    await _document.set(goals.toMap(), SetOptions(merge: true));
  }
}
