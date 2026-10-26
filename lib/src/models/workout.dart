import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.category,
    required this.duration,
    required this.date,
    this.durationUnit = 'minutes',
    this.sets,
    this.reps,
    this.createdAt,
  });

  final String id;
  final String name;
  final String category;
  final int duration;
  /// `duration` is stored in this unit; old records default to minutes.
  final String durationUnit;
  final int? sets;
  final int? reps;
  final DateTime date;
  final Timestamp? createdAt;

  int get durationInMinutes => durationUnit == 'seconds' ? (duration / 60).ceil() : duration;

  String get formattedDuration => '$duration ${durationUnit == 'seconds' ? 'sec' : 'min'}';

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'duration': duration,
        'durationUnit': durationUnit,
        'sets': sets,
        'reps': reps,
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
      durationUnit: data['durationUnit'] as String? ?? 'minutes',
      sets: (data['sets'] as num?)?.toInt(),
      reps: (data['reps'] as num?)?.toInt(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
