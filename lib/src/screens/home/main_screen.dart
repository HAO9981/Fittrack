import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../workout/workout_screen.dart';
import '../gyms/gym_finder_screen.dart';
import 'dashboard_screen.dart';

const _navInk = Color(0xFF9BFF3D);
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _selected = 0;
  final List<Widget> _pages = const [DashboardScreen(), WorkoutScreen(), NutritionScreen(), GymFinderScreen(), ProfileScreen()];
  @override Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _selected, children: _pages),
    bottomNavigationBar: NavigationBar(selectedIndex: _selected, onDestinationSelected: (index) => setState(() => _selected = index), height: 68, backgroundColor: const Color(0xFF0D120F), indicatorColor: const Color(0xFF26391D), labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: _navInk), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center_rounded, color: _navInk), label: 'Workout'),
        NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant_rounded, color: _navInk), label: 'Nutrition'),
        NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded, color: _navInk), label: 'Explore'),
        NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: _navInk), label: 'Profile'),
      ]),
  );
}
