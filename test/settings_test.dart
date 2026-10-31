import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/app.dart';
import 'package:movement_quest/data/app_settings.dart';
import 'package:movement_quest/screens/settings_screen.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'support/fake_stores.dart';

final class FakePreferences extends SharedPreferencesAsyncPlatform {
  final values = <String, String>{};

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async => values[key];

  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'preference adapter reloads all three values from a fresh store',
    () async {
      final preferences = FakePreferences();
      final original = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance = preferences;
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
      await PreferencesSettingsStore().save(
        const AppSettings(
          equipment: 'Resistance band',
          defaultEffort: 5,
          reducedMotion: true,
        ),
      );
      final reloaded = await PreferencesSettingsStore().load();
      expect(reloaded.equipment, 'Resistance band');
      expect(reloaded.defaultEffort, 5);
      expect(reloaded.reducedMotion, true);
      expect(preferences.values.keys, [PreferencesSettingsStore.key]);
      expect(
        () => AppSettings.decode(
          '{"equipment":"bad","defaultEffort":0,"reducedMotion":true}',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'settings preserve old values on failure and ignore concurrent saves',
    () async {
      final store = FakeSettingsStore();
      final controller = SettingsController(store);
      await controller.load();
      store.failSave = true;
      expect(await controller.save(const AppSettings(defaultEffort: 5)), false);
      expect(controller.value.defaultEffort, 3);
      store.failSave = false;
      store.pending = Completer<void>();
      final first = controller.save(const AppSettings(defaultEffort: 5));
      expect(await controller.save(const AppSettings(defaultEffort: 2)), false);
      store.pending!.complete();
      expect(await first, true);
      expect(store.saves, 2);
      expect(controller.value.defaultEffort, 5);
      controller.dispose();
    },
  );

  test('settings callback safely finishes after controller disposal', () async {
    final store = FakeSettingsStore();
    final controller = SettingsController(store);
    await controller.load();
    store.pending = Completer<void>();
    final result = controller.save(const AppSettings(reducedMotion: true));
    controller.dispose();
    store.pending!.complete();
    expect(await result, false);
  });

  testWidgets('settings load failure can retry and failed save keeps draft', (
    tester,
  ) async {
    final store = FakeSettingsStore()..failLoad = true;
    final controller = SettingsController(store);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsScreen(controller: controller)),
      ),
    );
    expect(
      find.text('Could not load your settings. Try again.'),
      findsOneWidget,
    );
    store.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    store.failSave = true;
    await tester.ensureVisible(find.text('Save settings'));
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(controller.value.reducedMotion, false);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    expect(
      find.textContaining('Your old settings still apply'),
      findsOneWidget,
    );
    store.failSave = false;
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(controller.value.reducedMotion, true);
    expect(find.text('Settings saved.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('reduced motion applies to new routes', (tester) async {
    final store = FakeSettingsStore()
      ..value = const AppSettings(reducedMotion: true);
    await tester.pumpWidget(
      MovementQuestApp(
        settingsStore: store,
        planStore: FakePlanStore(),
        logStore: FakeLogStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add plan'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Plan name'));
    expect(MediaQuery.disableAnimationsOf(context), true);
    expect(
      (ModalRoute.of(context)! as TransitionRoute).transitionDuration,
      Duration.zero,
    );
  });

  testWidgets('settings fit landscape with large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = SettingsController(FakeSettingsStore());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: SettingsScreen(controller: controller)),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Save settings'), 150);
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
