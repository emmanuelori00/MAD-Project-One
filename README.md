# Movement Quest

Movement Quest is an offline workout tracker. The goal is to let users
save workout plans, record sets, fix their history, and get a plan
suggestion based on their equipment.

## My part

I worked on the five-screen navigation, reusable plan cards, workout
controls, history controls, and settings.

The workout screen checks set entries, prevents repeated saves, and
asks before leaving an unfinished workout. The history screen supports
adding, correcting, and deleting entries when a data store is supplied.

I used SharedPreferences for equipment preference, starting effort,
and reduced motion.

## Current status

The screens and settings are implemented. The plan list still uses
examples, and the plan editor is a placeholder.

The workout and history screens still need the real database connected.
Set saving stays unavailable until that connection is ready.
The Gear Match helper also needs to be connected and checked against
the proposal.

## Run and check

From the project folder:

flutter pub get
flutter run
flutter analyze
flutter test

## Checks completed

All 19 automated tests passed, and Flutter analysis reported no issues.

The tests cover navigation, settings, workout controls, history changes,
validation, and failure recovery. Workout and history tests use fake
storage. Database persistence, offline restart, and the final APK still
need testing.
