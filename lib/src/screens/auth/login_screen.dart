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
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141B17),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF27332B)),
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: _lime, size: 21),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Welcome Back', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: _ink, height: 1.15)),
                  const SizedBox(height: 5),
                  const Text('Continue your fitness journey', style: TextStyle(fontSize: 13, color: _muted)),
                  const SizedBox(height: 25),
                  const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'example@gmail.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
                      contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    ),
                    validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address.' : null,
                  ),
                  const SizedBox(height: 14),
                  const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters.' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), minimumSize: const Size(0, 30)),
                      onPressed: _isLoading ? null : _resetPassword,
                      child: const Text('Forgot Password?', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _ink))
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(children: [
                    Expanded(child: Divider(color: Color(0xFF27332B))),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Or continue with', style: TextStyle(color: _muted, fontSize: 11))),
                    Expanded(child: Divider(color: Color(0xFF27332B))),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialSignInButton(icon: Icons.g_mobiledata_rounded, label: 'Google', onTap: () => _showMessage('Google sign-in is not configured yet.')),
                      const SizedBox(width: 16),
                      _SocialSignInButton(icon: Icons.apple, label: 'Apple', onTap: () => _showMessage('Apple sign-in is not configured yet.')),
                      const SizedBox(width: 16),
                      _SocialSignInButton(icon: Icons.facebook_rounded, label: 'Facebook', onTap: () => _showMessage('Facebook sign-in is not configured yet.')),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(fontSize: 11, color: _muted)),
                      TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 3), minimumSize: const Size(0, 32)),
                        onPressed: _isLoading ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text('Sign Up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SocialSignInButton extends StatelessWidget {
  const _SocialSignInButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(28),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: label == 'Facebook' ? const Color(0xFF1877F2) : const Color(0xFFF4F7F1),
        shape: BoxShape.circle,
        border: label == 'Apple' ? Border.all(color: const Color(0xFF465047)) : null,
      ),
      child: Icon(icon, size: label == 'Google' ? 30 : 24, color: label == 'Facebook' ? Colors.white : const Color(0xFF111713)),
    ),
  );
}
