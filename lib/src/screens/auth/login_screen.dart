import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'register_screen.dart';

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  @override void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuthService.instance.signInWithEmail(_emailController.text, _passwordController.text);
    } on firebase_auth.FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } catch (_) {
      _showMessage('Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage('Enter your email address first.');
      return;
    }
    try {
      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent. Check your inbox.');
    } on firebase_auth.FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Unable to send reset email.');
    } catch (_) {
      _showMessage('Unable to send reset email. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authErrorMessage(firebase_auth.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password': return 'Incorrect email or password.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'too-many-requests': return 'Too many attempts. Please wait and try again.';
      default: return error.message ?? 'Unable to sign in.';
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: Container(width: 54, height: 54, decoration: BoxDecoration(color: _lime, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.bolt_rounded, size: 32, color: _ink))),
        const SizedBox(height: 28),
        const Text('Welcome back,', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: _ink, height: 1.12)),
        const Text('let’s get moving.', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: _ink, height: 1.12)),
        const SizedBox(height: 10),
        const Text('Your fitness journey continues here.', style: TextStyle(fontSize: 14, color: _muted)),
        const SizedBox(height: 26),
        Container(height: 150, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)), clipBehavior: Clip.antiAlias, child: Stack(children: [
          Positioned(right: -24, top: -44, child: Container(width: 180, height: 180, decoration: BoxDecoration(color: _lime.withValues(alpha: 0.16), shape: BoxShape.circle))),
          Positioned(right: 14, bottom: -72, child: Container(width: 180, height: 180, decoration: BoxDecoration(border: Border.all(color: _lime.withValues(alpha: 0.4), width: 2), shape: BoxShape.circle))),
          const Padding(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.directions_run_rounded, color: _lime, size: 32),
            SizedBox(height: 9),
            Text('Small steps.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Stronger every day.', style: TextStyle(color: Color(0xFFD5D9D2), fontSize: 13)),
          ])),
        ])),
        const SizedBox(height: 26),
        const Text('Email address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 7),
        TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address.' : null),
        const SizedBox(height: 16),
        const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 7),
        TextFormField(controller: _passwordController, obscureText: _hidePassword, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _signIn(), decoration: InputDecoration(hintText: 'Enter your password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters.' : null),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _isLoading ? null : _resetPassword, child: const Text('Forgot password?'))),
        const SizedBox(height: 8),
        SizedBox(height: 54, child: ElevatedButton(onPressed: _isLoading ? null : _signIn, child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _ink)) : const Text('Sign in'))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text("Don't have an account? ", style: TextStyle(fontSize: 13, color: _muted)),
          TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('Create account', style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ])),
    )),
  );
}
