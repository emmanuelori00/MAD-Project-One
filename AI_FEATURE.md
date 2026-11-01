# Workout suggestions

Gear Match helps users pick a saved workout. It uses simple rules and works without internet.

Each plan gets:

- 2 points if it matches the user’s equipment.
- 1 point if it wasn’t the last finished workout.

The plan with the most points comes first. If plans tie, the lower plan ID wins. The app skips rules when there’s no equipment preference or finished workout history.

The simpler version only checks equipment. It helps us see whether checking the last workout improves the suggestion.

## Test results — October 31, 2026

| Test | What happened |
|---|---|
| Normal plans | Both versions picked the expected plan. |
| No plans | The app asked the user to add a plan. |
| No finished workouts | Both versions picked the matching plan with the lower ID. |
| Invalid saved data | The app showed an error instead of a suggestion. |
| Tied scores | Gear Match picked the expected plan. The simpler version picked the last-used plan. |
| Wanting the same workout again | The simpler version picked what the example user wanted. Gear Match picked a different plan. |

Both versions picked the expected choice in **3 out of 4 valid examples**. Empty and invalid examples were checked separately. These were made-up examples, so they don’t prove what real users will prefer.

Gear Match can help someone try a different workout, but sometimes they want to repeat one. That’s why users can skip the suggestion or choose another plan. Opening a suggestion doesn’t start the workout.

All **40 selected helper and screen tests passed**. Saved data also stayed after closing and reopening the app without internet on Pixel 9 and InClass09 Test. Details are in `docs/MQ14_TEST_RESULTS.md`.

The rules stayed the same after testing. Suggestions remain optional. The helper doesn’t decide whether a workout is safe or how hard someone should exercise.
