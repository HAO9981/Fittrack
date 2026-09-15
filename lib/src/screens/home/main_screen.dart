import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../workout/workout_screen.dart';
import 'dashboard_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    WorkoutScreen(),
    NutritionScreen(),
    Center(child: Text('Gyms Map', style: TextStyle(fontSize: 18))),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _pages[_selected]),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selected,
          onTap: (index) => setState(() => _selected = index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Nutrition'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Gyms'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
}
