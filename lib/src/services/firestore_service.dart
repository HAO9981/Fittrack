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

  String _savedGymDocumentId(places.PlaceData gym) {
    final placeId = gym.id.trim();
    if (placeId.isNotEmpty) return placeId;

    final name = gym.displayName?.text?.trim() ?? 'gym';
    final latitude = gym.location?.latitude.toStringAsFixed(6) ?? 'unknown';
    final longitude = gym.location?.longitude.toStringAsFixed(6) ?? 'unknown';
    final safe = '$name-$latitude-$longitude'
        .replaceAll(RegExp(r'[/\\#?]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return 'fallback_$safe';
  }

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
    final ids = <String>{};
    for (final doc in snapshot.docs) {
      final placeId = doc.data()['placeId'];
      ids.add(placeId is String && placeId.isNotEmpty ? placeId : doc.id);
    }

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
    final documentId = _savedGymDocumentId(gym);
    final placeId = gym.id.trim();

    await _savedGyms(uid).doc(documentId).set({
      'placeId': placeId,
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

    // Keep the old field in sync for users that already have this field.
    if (placeId.isNotEmpty) {
      await _users.doc(uid).set({
        'savedGymIds': FieldValue.arrayUnion([placeId]),
      }, SetOptions(merge: true));
    }
  }

  Future<void> removeSavedGym(String uid, String placeId) async {
    if (placeId.trim().isNotEmpty) {
      await _savedGyms(uid).doc(placeId).delete();
      await _users.doc(uid).set({
        'savedGymIds': FieldValue.arrayRemove([placeId]),
      }, SetOptions(merge: true));
      return;
    }

    // Some Places responses can have an empty ID. Remove the matching saved
    // record by its stored placeId instead of calling Firestore doc('').
    final snapshot = await _savedGyms(uid)
        .where('placeId', isEqualTo: '')
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // TODO(Firebase): Add workout, meal, history, and progress methods in later phases.
}
