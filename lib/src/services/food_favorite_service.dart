import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class FoodFavorite {
  const FoodFavorite({
    required this.name,
    required this.category,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.portion = '',
    this.nutritionNote = '',
  });

  final String name;
  final String category;
  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String portion;
  final String nutritionNote;

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'portion': portion,
    'nutritionNote': nutritionNote,
  };

  factory FoodFavorite.fromMap(Map<String, dynamic> map) => FoodFavorite(
    name: map['name'] as String? ?? '',
    category: map['category'] as String? ?? 'Snack',
    calories: (map['calories'] as num?)?.toInt() ?? 0,
    proteinGrams: (map['proteinGrams'] as num?)?.toDouble() ?? 0,
    carbsGrams: (map['carbsGrams'] as num?)?.toDouble() ?? 0,
    fatGrams: (map['fatGrams'] as num?)?.toDouble() ?? 0,
    portion: map['portion'] as String? ?? '',
    nutritionNote: map['nutritionNote'] as String? ?? '',
  );
}

class FoodFavoriteService {
  FoodFavoriteService._();
  static final FoodFavoriteService instance = FoodFavoriteService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDocument {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) throw StateError('Please sign in to manage favorite foods.');
    return _firestore.collection('users').doc(user.uid);
  }

  Stream<List<FoodFavorite>> watchFavorites() {
    try {
      return _userDocument.snapshots().map((snapshot) {
        final raw = snapshot.data()?['favoriteFoods'];
        if (raw is! List) return <FoodFavorite>[];
        return raw
            .whereType<Map>()
            .map((item) => FoodFavorite.fromMap(Map<String, dynamic>.from(item)))
            .where((item) => item.name.trim().isNotEmpty)
            .toList();
      });
    } on StateError catch (error) {
      return Stream<List<FoodFavorite>>.error(error);
    }
  }

  Future<void> saveFavorite(FoodFavorite favorite) async {
    if (favorite.name.trim().isEmpty) throw ArgumentError('Food name is required.');
    final document = _userDocument;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final raw = snapshot.data()?['favoriteFoods'];
      final favorites = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      favorites.removeWhere((item) =>
          (item['name'] as String? ?? '').trim().toLowerCase() ==
          favorite.name.trim().toLowerCase());
      favorites.add(favorite.toMap());
      transaction.set(document, {'favoriteFoods': favorites}, SetOptions(merge: true));
    });
  }

  Future<void> removeFavorite(String name) async {
    final document = _userDocument;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final raw = snapshot.data()?['favoriteFoods'];
      final favorites = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      favorites.removeWhere((item) =>
          (item['name'] as String? ?? '').trim().toLowerCase() ==
          name.trim().toLowerCase());
      transaction.set(document, {'favoriteFoods': favorites}, SetOptions(merge: true));
    });
  }
}
