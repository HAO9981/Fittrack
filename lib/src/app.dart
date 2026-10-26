import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'services/auth_service.dart';
import 'widgets/app_error.dart';
import 'widgets/app_loading.dart';

const fitTrackLime = Color(0xFF9BFF3D);
const fitTrackInk = Color(0xFFF4F7F1);
const fitTrackBackground = Color(0xFF080D0B);
const fitTrackSurface = Color(0xFF141B17);
const fitTrackBorder = Color(0xFF27332B);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: fitTrackLime, brightness: Brightness.dark).copyWith(
      primary: fitTrackLime, onPrimary: Color(0xFF10170D), surface: fitTrackSurface, onSurface: fitTrackInk,
    );
    return MaterialApp(
      title: 'FitTrack', debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: fitTrackBackground,
        appBarTheme: const AppBarTheme(backgroundColor: fitTrackBackground, foregroundColor: fitTrackInk, elevation: 0, surfaceTintColor: Colors.transparent),
        cardTheme: CardThemeData(color: fitTrackSurface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: fitTrackSurface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: fitTrackBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE8EBE5))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: fitTrackLime, width: 1.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          backgroundColor: fitTrackLime, foregroundColor: Color(0xFF10170D), elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        )),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: fitTrackSurface, selectedItemColor: fitTrackLime, unselectedItemColor: Color(0xFF8A9189),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11), unselectedLabelStyle: TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed, elevation: 0,
        ),
        dividerColor: fitTrackBorder,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AppUser?>(
    stream: FirebaseAuthService.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const AppLoading(message: 'Checking your session...');
      if (snapshot.hasError) return AppError(message: 'Unable to check your sign-in status.');
      return snapshot.data == null ? const LoginScreen() : const MainScreen();
    },
  );
}
