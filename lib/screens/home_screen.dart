import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/training_log_store.dart';
import '../data/workout_plan.dart';
import '../data/workout_plan_store.dart';
import 'history_screen.dart';
import 'plan_editor_screen.dart';
import 'plans_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.planStore,
    required this.logStore,
  });

  final SettingsController settings;
  final WorkoutPlanStore planStore;
  final TrainingLogStore logStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _historyRefresh = 0;
  int _finishedWorkouts = 0;
  List<WorkoutPlan> _plans = [];
  bool _loaded = false;
  bool _busy = false;
  bool _reloadPending = false;
  String? _error;
  String? _message;

  bool get _ready => _loaded && !_busy && _error == null;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({bool refreshHistory = false}) async {
    if (refreshHistory) setState(() => _historyRefresh++);
    if (_busy) {
      _reloadPending = true;
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final plans = await widget.planStore.readPlans();
      final entries = await widget.logStore.readAll();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _finishedWorkouts = finishedSessionCount(entries);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your workouts. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_reloadPending) {
          _reloadPending = false;
          _reload();
        }
      }
    }
  }

  Route<T> _route<T>(Widget screen) => MediaQuery.disableAnimationsOf(context)
      ? PageRouteBuilder<T>(
          pageBuilder: (_, _, _) => screen,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        )
      : MaterialPageRoute<T>(builder: (_) => screen);

  Future<WorkoutPlan?> _openEditor([WorkoutPlan? plan]) async {
    if (!_ready) return null;
    if (plan == null && (!widget.settings.loaded || widget.settings.busy)) {
      return null;
    }
    final saved = await Navigator.of(context).push<WorkoutPlan>(
      _route<WorkoutPlan>(
        PlanEditorScreen(
          store: widget.planStore,
          defaults: widget.settings.value,
          plan: plan,
        ),
      ),
    );
    if (!mounted || saved == null) return saved;
    setState(() => _message = 'Plan saved.');
    await _reload(refreshHistory: true);
    return saved;
  }

  Future<void> _openWorkout(WorkoutPlan plan) async {
    if (!_ready) return;
    var current = plan;
    await Navigator.of(context).push<void>(
      _route<void>(
        WorkoutScreen(
          planName: plan.title,
          equipment: plan.equipmentTag,
          planNote: plan.planNote,
          effortPreference: plan.effortPreference,
          workoutId: plan.id,
          logStore: widget.logStore,
          planStore: widget.planStore,
          onEdit: () async {
            final saved = await _openEditor(current);
            if (saved != null) current = saved;
            return saved;
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _message = null);
    await _reload(refreshHistory: true);
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) _historyRefresh++;
    });
    if (index == 0) _reload();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Workout plans', 'Workout history', 'Settings'];
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) _selectTab(0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]),
          leading: _selectedIndex == 0
              ? null
              : BackButton(onPressed: () => _selectTab(0)),
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              PlansScreen(
                plans: _plans,
                loaded: _loaded,
                busy: _busy,
                error: _error,
                message: _message,
                finishedWorkouts: _finishedWorkouts,
                settingsReady: widget.settings.loaded && !widget.settings.busy,
                onRetry: _reload,
                onAddPlan: () => _openEditor(),
                onEditPlan: _openEditor,
                onOpenPlan: _openWorkout,
              ),
              HistoryScreen(
                store: widget.logStore,
                plans: _plans
                    .map(
                      (plan) =>
                          WorkoutReference(id: plan.id!, title: plan.title),
                    )
                    .toList(),
                refreshToken: _historyRefresh,
                onChanged: _reload,
              ),
              SettingsScreen(controller: widget.settings),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
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
