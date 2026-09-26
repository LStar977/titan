# Changelog

## 1.1 (build 5) — the gym-floor redesign

### App Store "What's New" (paste as-is)

```
A redesign built around the gym floor.

• Focus mode: one exercise at a time with a big set logger — bigger numbers, bigger buttons, one-tap LOG SET.
• A rest timer that works with your phone locked: a sound and a banner when rest is up, plus what's next.
• Records light up the moment they fall — now including rep records on push-ups and pull-ups.
• Kilograms: switch between lb and kg any time; your history converts with it.
• Swap an exercise when the machine is taken, add a warm-up ramp in one tap, and leave notes that come back next session.
• Hit the top of your rep range and the next session starts one step heavier.
• Edit or delete past workouts, repeat any workout, or save it as a routine.
• Progress: weekly volume chart, sets per muscle, and a strength trend for every lift.
• Exercise pages now show your rep maxes and a proper e1RM chart.
• Share a workout card to your stories.
• A workout in progress survives the app being closed.
```

### Fixed
- A workout in progress was lost if iOS closed the app mid-session; it now comes back as the active workout, and anything left open for over 12 hours is closed out automatically.
- The rest timer only alerted while the app was on screen; it now schedules a local notification.
- VALKYRIE: rest-timer digits were white on a white card and became unreadable as the countdown drained.
- The exercise picker added exercises alphabetically instead of in the order they were tapped.
- Several sets on the same exercise could all be flagged as PRs in one session; now only the best one is.
- Program exercises missing from the library showed a blank name when a workout started.
- XP never came back off when a workout was removed; rank is now derived from the log itself.
- Cardio and stretching pages showed "0 lb" stats; they now show minutes.

### New
- Focus-mode workout logger: the current exercise expands with a large set panel; the rest collapse to progress rows, and focus advances automatically — alternating between superset partners, with rest after each round.
- Rest dock with countdown ring, "up next", ±15 s and skip; rest alerts via local notifications.
- PR banner, rank-up moment, muscles-worked map, comparison with last time, and a shareable image card on the finish screen.
- lb / kg units (everything is still stored in pounds, so history converts losslessly).
- Double progression, warm-up ramps, exercise swap, per-exercise notes, move up/down, rename, auto-named custom workouts ("Chest & Arms").
- Inline plate math for barbell lifts ("Per side: 45 + 25").
- History month feed with a monthly summary; edit, delete, repeat and save-as-routine for past workouts, with PR flags re-derived after edits.
- Progress: period summary with deltas, 12-week volume chart, sets-or-volume heat map, key-lift trends.
- Exercise detail: Swift Charts e1RM chart with record markers, rep-max table.
- Profile: lifetime totals, full Settings screen, CSV export.
- First-run onboarding: name, units, weekly goal, rest alerts.
- App Store review prompt after a workout with a record in it (at most every four months).

### Design system
- Type floor raised to 11 pt; key numbers much larger.
- Every tappable control is at least 44 pt.
- Shared components (DesignSystem.swift): ScreenTitle, SectionHeader, PillPicker, StepperField, NumberField, ProgressRing, RankEmblem, RecordToast, EmptyStateCard.
- Press feedback on every button; softer cards with a hint of depth in the light theme.

### Data model (automatic migration — no data loss)
- `Workout.notes`, `WorkoutEntry.notes`, `WorkoutEntry.targetLow`, `WorkoutEntry.targetHigh`, all with defaults.
