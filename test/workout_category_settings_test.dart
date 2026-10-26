import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/src/services/workout_category_service.dart';

void main() {
  group('WorkoutCategorySettings', () {
    test('uses empty lists when the profile has no category settings', () {
      final settings = WorkoutCategorySettings.fromMap(null);

      expect(settings.custom, isEmpty);
      expect(settings.hidden, isEmpty);
    });

    test('reads custom and hidden values from the user settings map', () {
      final settings = WorkoutCategorySettings.fromMap({
        'customCategories': ['Mobility', 'Powerlifting'],
        'hiddenCategories': ['Flexibility'],
      });

      expect(settings.custom, ['Mobility', 'Powerlifting']);
      expect(settings.hidden, ['Flexibility']);
    });
  });
}
