import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'plan_editor_screen.dart';
import 'plans_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _openEditor([String? planName]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlanEditorScreen(planName: planName),
      ),
    );
  }

  void _openWorkout(String name, String equipment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            WorkoutScreen(planName: name, equipment: equipment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Workout plans', 'Workout history', 'Settings'];

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]),
          leading: _selectedIndex == 0
              ? null
              : BackButton(
                  onPressed: () {
                    setState(() => _selectedIndex = 0);
                  },
                ),
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              PlansScreen(
                onAddPlan: () => _openEditor(),
                onEditPlan: _openEditor,
                onOpenPlan: _openWorkout,
              ),
              const HistoryScreen(),
              const SettingsScreen(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.fitness_center),
              label: 'Plans',
            ),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
