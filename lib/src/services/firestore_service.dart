import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart' as places;

import '../models/app_user.dart';
import '../models/user_profile.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _savedGyms(String uid) =>
      _users.doc(uid).collection('savedGyms');

  Future<void> createUserProfile(AppUser user) async {
    final profile = UserProfile.initial(user);
    await _users.doc(user.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final document = await _users.doc(uid).get();
    return document.exists ? UserProfile.fromDocument(document) : null;
  }

  Stream<UserProfile?> userProfileStream(String uid) =>
      _users.doc(uid).snapshots().map(
            (document) => document.exists
                ? UserProfile.fromDocument(document)
                : null,
          );

  Future<void> updateUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<Set<String>> getSavedGymIds(String uid) async {
    final snapshot = await _savedGyms(uid).get();
    final ids = snapshot.docs.map((doc) => doc.id).toSet();

    // Keep compatibility with the original savedGymIds field.
    final userDocument = await _users.doc(uid).get();
    final legacyIds = userDocument.data()?['savedGymIds'];
    if (legacyIds is List) {
      ids.addAll(legacyIds.whereType<String>());
    }

    return ids;
  }

  Future<List<Map<String, dynamic>>> getSavedGyms(String uid) async {
    final snapshot = await _savedGyms(uid).orderBy('savedAt', descending: true).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> saveGym(String uid, places.PlaceData gym) async {
    await _savedGyms(uid).doc(gym.id).set({
      'placeId': gym.id,
      'name': gym.displayName?.text,
      'address': gym.formattedAddress,
      'rating': gym.rating,
      'ratingCount': gym.userRatingCount,
      'phone': gym.nationalPhoneNumber,
      'websiteUri': gym.websiteUri,
      'googleMapsUri': gym.googleMapsUri,
      'latitude': gym.location?.latitude,
      'longitude': gym.location?.longitude,
      'currentOpeningHours': gym.currentOpeningHours,
      'regularOpeningHours': gym.regularOpeningHours,
      'savedAt': FieldValue.serverTimestamp(),
    });

    // Keep the old field in sync so existing users do not lose their saved IDs.
    await _users.doc(uid).set({
      'savedGymIds': FieldValue.arrayUnion([gym.id]),
    }, SetOptions(merge: true));
  }

  Future<void> removeSavedGym(String uid, String placeId) async {
    await _savedGyms(uid).doc(placeId).delete();
    await _users.doc(uid).set({
      'savedGymIds': FieldValue.arrayRemove([placeId]),
    }, SetOptions(merge: true));
  }

  // TODO(Firebase): Add workout, meal, history, and progress methods in later phases.
}
