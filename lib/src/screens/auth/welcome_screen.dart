import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'register_screen.dart';

const _welcomeLime = Color(0xFF9BFF3D);

/// First screen for signed-out users; authentication remains handled by Firebase.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/workouts/running.jpg', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    const Color(0xFF080D0B).withValues(alpha: 0.5),
                    const Color(0xFF080D0B),
                  ],
                  stops: const [0, 0.45, 0.82],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    const Icon(Icons.bolt_rounded, size: 54, color: _welcomeLime),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5),
                        children: [
                          TextSpan(text: 'Fit'),
                          TextSpan(text: 'Track', style: TextStyle(color: _welcomeLime)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Your Fitness Journey,\nSmarter with AI', style: TextStyle(color: Color(0xFFD1D8D2), fontSize: 19, height: 1.3)),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text('Get Started'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF465047)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
