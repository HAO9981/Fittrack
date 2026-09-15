import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/user_profile.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  Future<void> createUserProfile(AppUser user) async {
    final profile = UserProfile.initial(user);
    await _users.doc(user.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final document = await _users.doc(uid).get();
    return document.exists ? UserProfile.fromDocument(document) : null;
  }

  Stream<UserProfile?> userProfileStream(String uid) => _users.doc(uid).snapshots().map(
        (document) => document.exists ? UserProfile.fromDocument(document) : null,
      );

  Future<void> updateUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  // TODO(Firebase): Add workout, meal, history, and progress methods in later phases.
}
