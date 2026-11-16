import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  const Meal({
    required this.id,
    required this.foodName,
    required this.category,
    required this.calories,
    required this.date,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.portion,
    this.nutritionNote,
    this.createdAt,
  });

  final String id;
  final String foodName;
  final String category;
  final int calories;
  final DateTime date;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String? portion;
  final String? nutritionNote;
  final Timestamp? createdAt;

  Map<String, dynamic> toMap() => {
        'foodName': foodName,
        'category': category,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        if (portion != null && portion!.isNotEmpty) 'portion': portion,
        if (nutritionNote != null && nutritionNote!.isNotEmpty)
          'nutritionNote': nutritionNote,
        'date': Timestamp.fromDate(date),
        if (createdAt != null) 'createdAt': createdAt,
      };

  factory Meal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    return Meal(
      id: document.id,
      foodName: data['foodName'] as String? ?? '',
      category: data['category'] as String? ?? 'Snack',
      calories: (data['calories'] as num?)?.toInt() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      proteinGrams: (data['proteinGrams'] as num?)?.toDouble() ?? 0,
      carbsGrams: (data['carbsGrams'] as num?)?.toDouble() ?? 0,
      fatGrams: (data['fatGrams'] as num?)?.toDouble() ?? 0,
      portion: data['portion'] as String?,
      nutritionNote: data['nutritionNote'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
