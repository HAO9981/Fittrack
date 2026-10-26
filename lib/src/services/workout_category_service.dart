import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Categories maintained for the signed-in user. Historical workout values are
/// intentionally not rewritten when a category is renamed or removed.
class WorkoutCategorySettings {
  const WorkoutCategorySettings({
    this.custom = const [],
    this.hidden = const [],
  });

  final List<String> custom;
  final List<String> hidden;

  factory WorkoutCategorySettings.fromMap(Map<String, dynamic>? data) {
    List<String> read(String key) => (data?[key] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return WorkoutCategorySettings(
      custom: read('customCategories'),
      hidden: read('hiddenCategories'),
    );
  }
}

class WorkoutCategoryService {
  WorkoutCategoryService._();
  static final instance = WorkoutCategoryService._();

  static const systemCategories = [
    'Strength',
    'Cardio',
    'Full Body',
    'Flexibility',
    'HIIT',
    'Other',
  ];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDocument {
    final user = FirebaseAuthService.instance.currentUser;
    if (user == null) {
      throw StateError('Please sign in to manage workout categories.');
    }
    return _firestore.collection('users').doc(user.uid);
  }

  Stream<WorkoutCategorySettings> watch() {
    try {
      return _userDocument.snapshots().map(
        (doc) => WorkoutCategorySettings.fromMap(
          doc.data()?['workoutCategorySettings'] as Map<String, dynamic>?,
        ),
      );
    } on StateError catch (error) {
      return Stream<WorkoutCategorySettings>.error(error);
    }
  }

  Future<void> _save(WorkoutCategorySettings settings) => _userDocument.set({
    'workoutCategorySettings': {
      'customCategories': settings.custom,
      'hiddenCategories': settings.hidden,
      'updatedAt': FieldValue.serverTimestamp(),
    },
  }, SetOptions(merge: true));

  Future<void> add(String name, WorkoutCategorySettings current) async {
    final category = _validatedName(name);
    _ensureUnique(category, [...systemCategories, ...current.custom]);
    await _save(
      WorkoutCategorySettings(
        custom: [...current.custom, category],
        hidden: current.hidden,
      ),
    );
  }

  Future<void> rename(
    String oldName,
    String newName,
    WorkoutCategorySettings current,
  ) async {
    final category = _validatedName(newName);
    if (!current.custom.contains(oldName)) {
      throw StateError('Only custom categories can be renamed.');
    }
    _ensureUnique(category, [
      ...systemCategories,
      ...current.custom.where((item) => item != oldName),
    ]);
    await _save(
      WorkoutCategorySettings(
        custom: current.custom
            .map((item) => item == oldName ? category : item)
            .toList(),
        hidden: current.hidden
            .map((item) => item == oldName ? category : item)
            .toList(),
      ),
    );
  }

  Future<void> delete(String name, WorkoutCategorySettings current) async {
    if (!current.custom.contains(name)) {
      throw StateError('Only custom categories can be deleted.');
    }
    await _save(
      WorkoutCategorySettings(
        custom: current.custom.where((item) => item != name).toList(),
        hidden: current.hidden.where((item) => item != name).toList(),
      ),
    );
  }

  Future<void> setVisible(
    String name,
    bool visible,
    WorkoutCategorySettings current,
  ) async {
    final hidden = current.hidden.toSet();
    if (visible) {
      hidden.remove(name);
    } else {
      hidden.add(name);
    }
    await _save(
      WorkoutCategorySettings(custom: current.custom, hidden: hidden.toList()),
    );
  }

  String _validatedName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > 30) {
      throw ArgumentError('Category names must be 1 to 30 characters.');
    }
    return name;
  }

  void _ensureUnique(String name, List<String> existing) {
    if (existing.any((item) => item.toLowerCase() == name.toLowerCase())) {
      throw ArgumentError('A category with this name already exists.');
    }
  }
}
