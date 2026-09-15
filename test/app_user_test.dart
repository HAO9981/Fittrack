import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/src/models/app_user.dart';

void main() {
  test('AppUser converts to and from a map', () {
    final user = AppUser(
      uid: 'user-1',
      email: 'fittrack@example.com',
      displayName: 'FitTrack User',
    );

    final restoredUser = AppUser.fromMap(user.toMap());

    expect(restoredUser.uid, user.uid);
    expect(restoredUser.email, user.email);
    expect(restoredUser.displayName, user.displayName);
  });
}
