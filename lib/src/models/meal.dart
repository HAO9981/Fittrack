import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  const Meal({
    required this.id,
    required this.foodName,
    required this.category,
    required this.calories,
    required this.date,
    this.createdAt,
  });

  final String id;
  final String foodName;
  final String category;
  final int calories;
  final DateTime date;
  final Timestamp? createdAt;

  Map<String, dynamic> toMap() => {
        'foodName': foodName,
        'category': category,
        'calories': calories,
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
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
