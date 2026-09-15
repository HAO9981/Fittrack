import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal.dart';
import 'auth_service.dart';

class NutritionService {
  NutritionService._();
  static final NutritionService instance = NutritionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _userId {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) throw StateError('Please sign in before managing meals.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _meals =>
      _firestore.collection('users').doc(_userId).collection('meals');

  Stream<List<Meal>> getMeals() {
    try {
      return _meals.orderBy('date', descending: true).snapshots().map(
            (snapshot) => snapshot.docs.map(Meal.fromFirestore).toList(),
          );
    } on StateError catch (error) {
      return Stream<List<Meal>>.error(error);
    }
  }

  Stream<List<Meal>> getMealsByDate(DateTime date) {
    try {
      final selectedDate = DateTime(date.year, date.month, date.day);
      final nextDate = selectedDate.add(const Duration(days: 1));
      return _meals
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDate))
          .where('date', isLessThan: Timestamp.fromDate(nextDate))
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Meal.fromFirestore).toList());
    } on StateError catch (error) {
      return Stream<List<Meal>>.error(error);
    }
  }

  /// Returns only the latest meals needed by the dashboard.
  Stream<List<Meal>> getRecentMeals({int limit = 3, Duration? lookback}) {
    try {
      Query<Map<String, dynamic>> query = _meals;
      if (lookback != null) {
        final cutoff = Timestamp.fromDate(DateTime.now().subtract(lookback));
        query = query.where('date', isGreaterThanOrEqualTo: cutoff);
      }

      return query
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Meal.fromFirestore).toList());
    } on StateError catch (error) {
      return Stream<List<Meal>>.error(error);
    }
  }

  Stream<List<Meal>> getTodayMeals() {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return _meals
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(Meal.fromFirestore).toList());
    } on StateError catch (error) {
      return Stream<List<Meal>>.error(error);
    }
  }

  Future<void> addMeal(Meal meal) async {
    final document = _meals.doc();
    await document.set({
      ...meal.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMeal(Meal meal) async {
    if (meal.id.isEmpty) throw ArgumentError('The meal ID is missing.');
    await _meals.doc(meal.id).update(meal.toMap());
  }

  Future<void> deleteMeal(String mealId) async {
    if (mealId.isEmpty) throw ArgumentError('The meal ID is missing.');
    await _meals.doc(mealId).delete();
  }
}
