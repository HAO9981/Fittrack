import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _bg = Color(0xFF080D0B);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  @override void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = await FirebaseAuthService.instance.signUpWithEmail(email: _emailController.text, password: _passwordController.text, displayName: _nameController.text);
      await FirestoreService.instance.createUserProfile(user);
      if (mounted) Navigator.of(context).pop();
    } on firebase_auth.FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } catch (_) {
      _showMessage('Account created, but the profile could not be saved. Please sign in and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authErrorMessage(firebase_auth.FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use': return 'An account already exists for this email.';
      case 'weak-password': return 'Choose a stronger password of at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      default: return error.message ?? 'Unable to create your account.';
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, title: const Text('Create account', style: TextStyle(fontWeight: FontWeight.w800, color: _ink))),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 136, decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF27332B))), child: Stack(children: [
          Positioned(right: -15, top: -50, child: Container(width: 170, height: 170, decoration: BoxDecoration(color: _lime.withValues(alpha: 0.17), shape: BoxShape.circle))),
          const Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.bolt_rounded, color: _lime, size: 29),
            SizedBox(height: 8),
            Text('Start your FitTrack journey', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
            Text('A healthier routine starts with you.', style: TextStyle(fontSize: 12, color: Color(0xFFD5D9D2))),
          ])),
        ])),
        const SizedBox(height: 24),
        const Text('Your name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 7),
        TextFormField(controller: _nameController, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'How should we call you?', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name.' : null),
        const SizedBox(height: 16),
        const Text('Email address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 7),
        TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address.' : null),
        const SizedBox(height: 16),
        const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 7),
        TextFormField(controller: _passwordController, obscureText: _hidePassword, textInputAction: TextInputAction.done, decoration: InputDecoration(hintText: 'At least 6 characters', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters.' : null),
        const SizedBox(height: 24),
        SizedBox(height: 54, child: ElevatedButton(onPressed: _isLoading ? null : _register, child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _ink)) : const Text('Create account'))),
        const SizedBox(height: 12),
        Center(child: TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Already have an account? Sign in', style: TextStyle(fontWeight: FontWeight.w700)))),
      ])),
    )),
  );
}
