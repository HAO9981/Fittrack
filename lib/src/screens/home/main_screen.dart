import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../workout/workout_screen.dart';
import 'dashboard_screen.dart';

const _navInk = Color(0xFF232824);
const _navMuted = Color(0xFF8A9189);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _selected = 0;
  final List<Widget> _pages = const [DashboardScreen(), WorkoutScreen(), NutritionScreen(), _GymsPlaceholder(), ProfileScreen()];
  @override Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _selected, children: _pages),
    bottomNavigationBar: NavigationBar(selectedIndex: _selected, onDestinationSelected: (index) => setState(() => _selected = index), height: 68, backgroundColor: Colors.white, indicatorColor: const Color(0xFFEAF7D9), labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: _navInk), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center_rounded, color: _navInk), label: 'Workouts'),
        NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant_rounded, color: _navInk), label: 'Nutrition'),
        NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded, color: _navInk), label: 'Gyms'),
        NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: _navInk), label: 'Profile'),
      ]),
  );
}
class _GymsPlaceholder extends StatelessWidget {
  const _GymsPlaceholder();
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFFF6F7F4), appBar: AppBar(title: const Text('Gym Finder', style: TextStyle(fontWeight: FontWeight.w800))), body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 92, height: 92, decoration: BoxDecoration(color: const Color(0xFFEAF7D9), borderRadius: BorderRadius.circular(28)), child: const Icon(Icons.map_outlined, size: 42, color: _navInk)),
    const SizedBox(height: 18), const Text('Find your next workout spot', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navInk)),
    const SizedBox(height: 8), const Text('Gym discovery and nearby locations will appear here.', textAlign: TextAlign.center, style: TextStyle(color: _navMuted)),
    const SizedBox(height: 18), const Text('Gym Finder is not connected to a map service yet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _navMuted)),
  ]))));
}
