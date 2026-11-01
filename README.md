# Movement Quest

Movement Quest is an offline workout tracker. It saves workout plans
and sets on the device and suggests a saved plan using equipment
preferences and workout history.

## Using the app

1. Tap Add plan and enter a name, equipment, optional notes, and effort.
2. Open a plan, tap Start workout, and save each set.
3. Tap Finish workout after saving at least one set. Sets from the
   same session count as one finished workout.
4. Open History to add, correct, or delete a set. Deletion asks for
   confirmation. A plan with saved sets cannot be deleted.
5. Use Settings to save equipment preference, default effort, and
   reduced motion. New defaults do not overwrite existing plans.

The equipment filter narrows the plan list. Suggestions explain their
points. View plan opens the plan without starting it. Not now hides
the suggestion until related data changes.

## Storage and structure

WorkoutPlan and TrainingLog use SQLite. TrainingLog links each set to
a plan and groups sets by session key. SharedPreferences stores settings.

lib/screens contains the five screen roles.
lib/widgets contains shared cards and dialogs.
lib/data contains validation, storage, settings, and suggestion rules.

## Setup and checks

Install Flutter with Dart 3.13.2 or compatible and the Android SDK.
Start an Android emulator or connect an Android device.

From this folder, run:

flutter pub get
flutter run
flutter analyze
flutter test

## Review — October 31, 2026

All 53 automated tests passed. Flutter analysis found no issues.

Tests cover plan and set CRUD, validation, restricted deletion, session
counts, repeated saves, failure recovery, SQLite reopening, settings,
navigation, large text, landscape layouts, and suggestions.

Earlier Pixel 9 emulator checks confirmed saving sets, finishing a
workout, correcting reps, canceling deletion, and suggestion updates.

Offline checks passed on Pixel 9 and InClass09 Test. Plans, saved sets,
workout counts, and settings stayed saved after closing and reopening
the app.

Workout suggestion results are in `AI_FEATURE.md`. Both versions
matched the expected choice in 3 of 4 valid examples.

App structure is explained in `ARCHITECTURE.md`. Release APK
verification and final submission documents are still pending.

## Project board

https://app.clickup.com/90141781449/v/b/6-901422407533-2

The October 31 board shows 8 Done, 4 Review/Test, and 7 Backlog.
Review/Test exceeds the planned limit of two. PRs 1, 2, and 3 remain
open. The required October 24 snapshot was not found.

Current board views:
docs/evidence/2026-10-31-board-top.png
docs/evidence/2026-10-31-board-backlog-lower.png
