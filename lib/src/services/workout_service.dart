import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout.dart';
import 'auth_service.dart';

class WorkoutService {
  WorkoutService._();
  static final WorkoutService instance = WorkoutService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _userId {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) throw StateError('Please sign in before managing workouts.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _workouts =>
      _firestore.collection('users').doc(_userId).collection('workouts');

  Stream<List<Workout>> getWorkouts() {
    try {
      return _workouts.orderBy('date', descending: true).snapshots().map(
            (snapshot) => snapshot.docs.map(Workout.fromFirestore).toList(),
          );
    } on StateError catch (error) {
      return Stream<List<Workout>>.error(error);
    }
  }

  /// Returns only workouts from the requested recent period.
  /// This is intended for dashboard statistics and recent activity.
  Stream<List<Workout>> getRecentWorkouts({
    Duration lookback = const Duration(days: 7),
    int limit = 20,
  }) {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(lookback));
      return _workouts
          .where('date', isGreaterThanOrEqualTo: cutoff)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Workout.fromFirestore).toList());
    } on StateError catch (error) {
      return Stream<List<Workout>>.error(error);
    }
  }

  Stream<List<Workout>> getTodayWorkouts() {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return _workouts
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Workout.fromFirestore).toList());
    } on StateError catch (error) {
      return Stream<List<Workout>>.error(error);
    }
  }

  Future<void> addWorkout(Workout workout) async {
    final document = _workouts.doc();
    await document.set({
      ...workout.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWorkout(Workout workout) async {
    if (workout.id.isEmpty) throw ArgumentError('The workout ID is missing.');
    await _workouts.doc(workout.id).update(workout.toMap());
  }

  Future<void> deleteWorkout(String workoutId) async {
    if (workoutId.isEmpty) throw ArgumentError('The workout ID is missing.');
    await _workouts.doc(workoutId).delete();
  }
}
