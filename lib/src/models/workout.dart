import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.category,
    required this.duration,
    required this.date,
    this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final int duration;
  final DateTime date;
  final Timestamp? createdAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'duration': duration,
        'date': Timestamp.fromDate(date),
        if (createdAt != null) 'createdAt': createdAt,
      };

  factory Workout.fromFirestore(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    return Workout(
      id: document.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      duration: (data['duration'] as num?)?.toInt() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
