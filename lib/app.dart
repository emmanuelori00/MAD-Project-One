import 'package:flutter/material.dart';

import 'data/app_settings.dart';
import 'screens/home_screen.dart';

class MovementQuestApp extends StatefulWidget {
  const MovementQuestApp({super.key, this.settingsStore});

  final SettingsStore? settingsStore;

  @override
  State<MovementQuestApp> createState() => _MovementQuestAppState();
}

class _MovementQuestAppState extends State<MovementQuestApp> {
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
        home: HomeScreen(settings: _settings),
      ),
    );
  }
}
