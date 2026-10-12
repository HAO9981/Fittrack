import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.fitnessGoal,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String? email;
  final String displayName;
  final String? gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final String? fitnessGoal;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.initial(AppUser user) => UserProfile(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName ?? 'FitTrack User',
      );

  factory UserProfile.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    return UserProfile(
      uid: document.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String? ?? 'FitTrack User',
      gender: data['gender'] as String?,
      age: data['age'] as int?,
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      targetWeightKg: (data['targetWeightKg'] as num?)?.toDouble(),
      fitnessGoal: data['fitnessGoal'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'gender': gender,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'targetWeightKg': targetWeightKg,
        'fitnessGoal': fitnessGoal,
        'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
