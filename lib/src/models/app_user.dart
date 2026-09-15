import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  AppUser({required this.uid, this.email, this.displayName, this.photoUrl});

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        uid: m['uid'] as String,
        email: m['email'] as String?,
        displayName: m['displayName'] as String?,
        photoUrl: m['photoUrl'] as String?,
      );

  factory AppUser.fromFirebaseUser(firebase_auth.User user) => AppUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
}
