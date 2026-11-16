import 'package:flutter/material.dart';
import '../profile/profile_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../workout/workout_screen.dart';
import '../gyms/gym_finder_screen.dart';
import '../ai/ai_assistant_screen.dart';
import 'dashboard_screen.dart';
import '../../navigation/app_navigation.dart';

const _navLime = Color(0xFF9BFF3D);
const _navInk = Color(0xFFF4F7F1);
const _navMuted = Color(0xFF9AA69C);
const _navBg = Color(0xFF080D0B);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;

  void _selectPage(int index) {
    setState(() => _selected = index);
    Navigator.of(context).maybePop();
  }

  void _openAiAssistant() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(onMenuPressed: AppNavigation.openDrawer),
      const WorkoutScreen(),
      const NutritionScreen(),
      const GymFinderScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      key: AppNavigation.scaffoldKey,
      drawer: _FitTrackDrawer(
        selectedIndex: _selected,
        onSelectPage: _selectPage,
        onOpenAiAssistant: _openAiAssistant,
      ),
      body: IndexedStack(index: _selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (index) => setState(() => _selected = index),
        height: 68,
        backgroundColor: const Color(0xFF0D120F),
        indicatorColor: const Color(0xFF26391D),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: _navLime),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded, color: _navLime),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded, color: _navLime),
            label: 'Nutrition',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded, color: _navLime),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _navLime),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _FitTrackDrawer extends StatelessWidget {
  const _FitTrackDrawer({
    required this.selectedIndex,
    required this.onSelectPage,
    required this.onOpenAiAssistant,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onOpenAiAssistant;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: _navBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 16, 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _navLime,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.monitor_heart_rounded,
                        color: _navBg, size: 25),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'FitTrack',
                      style: TextStyle(
                        color: _navInk,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: _navMuted),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF27332B), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    title: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelectPage(0),
                  ),
                  const _DrawerSectionLabel('FITNESS'),
                  _DrawerGroup(
                    icon: Icons.fitness_center_rounded,
                    title: 'Workout',
                    selected: selectedIndex == 1,
                    initiallyExpanded: selectedIndex == 1,
                    children: [
                      'My Workouts',
                      'Exercises',
                      'Workout Progress',
                      'Workout Goals',
                      'Workout Calendar',
                      'AI Workout Analysis',
                      'Recommendations',
                    ],
                    onChildTap: () => onSelectPage(1),
                  ),
                  const _DrawerSectionLabel('NUTRITION'),
                  _DrawerGroup(
                    icon: Icons.restaurant_rounded,
                    title: 'Nutrition',
                    selected: selectedIndex == 2,
                    initiallyExpanded: selectedIndex == 2,
                    children: const ['Today\'s Meals', 'Meal History', 'Daily Intake'],
                    onChildTap: () => onSelectPage(2),
                  ),
                  const _DrawerSectionLabel('DISCOVER'),
                  _DrawerGroup(
                    icon: Icons.explore_rounded,
                    title: 'Explore',
                    selected: selectedIndex == 3,
                    initiallyExpanded: selectedIndex == 3,
                    children: const ['Gym Finder', 'Saved Gyms'],
                    onChildTap: () => onSelectPage(3),
                  ),
                  _DrawerItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'FitTrack AI',
                    selected: false,
                    onTap: onOpenAiAssistant,
                  ),
                  const _DrawerSectionLabel('PERSONAL'),
                  _DrawerGroup(
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    selected: selectedIndex == 4,
                    initiallyExpanded: selectedIndex == 4,
                    children: const [
                      'Personal Information',
                      'Weight Tracking',
                      'Fitness Goal',
                      'Settings',
                    ],
                    onChildTap: () => onSelectPage(4),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF27332B), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Row(
                children: const [
                  Icon(Icons.favorite_rounded, color: _navLime, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Build healthy habits, one day at a time.',
                    style: TextStyle(color: _navMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF78857B),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected ? _navLime : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: ListTile(
          dense: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          leading: Icon(icon,
              color: selected ? _navBg : _navInk, size: 21),
          title: Text(
            title,
            style: TextStyle(
              color: selected ? _navBg : _navInk,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          onTap: onTap,
        ),
      );
}

class _DrawerGroup extends StatelessWidget {
  const _DrawerGroup({
    required this.icon,
    required this.title,
    required this.selected,
    required this.initiallyExpanded,
    required this.children,
    required this.onChildTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final bool initiallyExpanded;
  final List<String> children;
  final VoidCallback onChildTap;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: _navLime.withValues(alpha: 0.08),
          highlightColor: _navLime.withValues(alpha: 0.04),
        ),
        child: ExpansionTile(
          key: PageStorageKey<String>('drawer-$title'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.only(left: 42, bottom: 5),
          leading: Icon(icon, color: selected ? _navLime : _navInk, size: 21),
          title: Text(
            title,
            style: TextStyle(
              color: selected ? _navLime : _navInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _navMuted),
          children: children
              .map(
                (item) => ListTile(
                  dense: true,
                  minLeadingWidth: 0,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item,
                      style:
                          const TextStyle(color: _navMuted, fontSize: 12)),
                  onTap: onChildTap,
                ),
              )
              .toList(),
        ),
      );
}
