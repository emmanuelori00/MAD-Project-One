# How Movement Quest works

Movement Quest works offline. It has five screen roles: Plans, Plan Editor, Workout, History, and Settings.

The screens handle buttons, forms, and what the user sees. Shared widgets keep plan cards and dialogs consistent. Data helpers handle saved records, settings, validation, and workout suggestions.

SQLite saves workout plans and training logs. Each log belongs to a plan. Sets from the same workout share a session key, so one finished workout counts once. A plan with saved sets cannot be deleted.

SharedPreferences saves equipment preference, default effort, and reduced motion.

Gear Match uses simple rules. Matching equipment adds two points, and choosing a different plan from the last finished workout adds one. Ties use the lower plan ID. Users can ignore the suggestion.

Save operations finish before the screen refreshes. The app blocks repeated saves while one is running and checks whether a screen is still open before updating it. Controllers and database connections are cleaned up when their owner closes.

Tests can use replacement storage helpers to check normal saves, errors, and recovery without changing real app data.
