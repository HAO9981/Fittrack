import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/app_user.dart';

abstract class AuthService {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> updateDisplayName(String displayName);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  AppUser? get currentUser => _user;

  AppUser? get _user {
    final user = _auth.currentUser;
    return user == null ? null : AppUser.fromFirebaseUser(user);
  }

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map((user) => user == null ? null : AppUser.fromFirebaseUser(user));

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return AppUser.fromFirebaseUser(credential.user!);
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(displayName.trim());
    await credential.user!.reload();
    return AppUser.fromFirebaseUser(_auth.currentUser!);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in before updating your profile.');

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) throw ArgumentError('Display name cannot be empty.');

    await user.updateDisplayName(trimmedName);
    await user.reload();
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
