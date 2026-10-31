import 'dart:async';

import 'package:flutter/material.dart';

import 'data/app_settings.dart';
import 'data/movement_quest_database.dart';
import 'data/training_log_store.dart';
import 'data/workout_plan_store.dart';
import 'screens/home_screen.dart';

class MovementQuestApp extends StatefulWidget {
  const MovementQuestApp({
    super.key,
    this.settingsStore,
    this.planStore,
    this.logStore,
  });

  final SettingsStore? settingsStore;
  final WorkoutPlanStore? planStore;
  final TrainingLogStore? logStore;

  @override
  State<MovementQuestApp> createState() => _MovementQuestAppState();
}

class _MovementQuestAppState extends State<MovementQuestApp> {
  late final _database = widget.planStore == null || widget.logStore == null
      ? MovementQuestDatabase()
      : null;
  late final _planStore = widget.planStore ?? _database!;
  late final _logStore = widget.logStore ?? _database!;
  late final _settings = SettingsController(
    widget.settingsStore ?? PreferencesSettingsStore(),
  );

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    unawaited(_database?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        title: 'Movement Quest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        ),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations || _settings.value.reducedMotion,
            ),
            child: child!,
          );
        },
        home: HomeScreen(
          settings: _settings,
          planStore: _planStore,
          logStore: _logStore,
        ),
      ),
    );
  }
}
