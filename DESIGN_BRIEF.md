# TITAN — Fitness Tracking App: Design Brief

This is the source-of-truth brief for the TITAN app. The prompt below is what we hand to
Claude Design. When the design comes back, the app gets built to match it, using this
document for feature scope.

## Brand

- Logo: cracked black spartan helmet with glowing purple eyes, wreathed in violet
  smoke/energy on a pure black background; "TITAN" wordmark in carved purple stone.
- Vibe: dark, powerful, mythic. The app should feel like a weapon, not a wellness journal.

## Color theme (extracted from logo)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#0A0A0F` | App background (near-black) |
| `surface` | `#131320` | Cards, sheets |
| `surface-2` | `#1C1C2E` | Elevated cards, inputs |
| `primary` | `#8B5CF6` | Primary actions, active states |
| `primary-bright` | `#A78BFA` | Glows, highlights, charts |
| `primary-deep` | `#5B21B6` | Pressed states, gradients |
| `accent-glow` | `#C4B5FD` | PR celebrations, glow edges |
| `text` | `#EDEDF4` | Primary text |
| `text-dim` | `#8E8EA3` | Secondary text |
| `success` | `#34D399` | Completed sets |
| `danger` | `#F87171` | Failed sets, destructive |

Dark mode only. Purple glow effects (soft outer glows, gradient edges) are a signature
element — used sparingly for emphasis (PRs, active timer, rank-ups).

## Feature scope

### Core (v1)
1. **Workout logging** — pick exercises, log sets × reps × weight. Optimized for speed
   between sets: large tap targets, +/- steppers, previous session's numbers shown as
   ghost values that can be confirmed with one tap. Per-set type: warm-up, working,
   failure, drop set. Set notes.
2. **Auto rest timer** — starts when a set is checked off; configurable per exercise;
   full-width countdown bar with skip/+30s.
3. **Routines** — build & save workout templates ("Push Day A"), start in one tap,
   reorder exercises, supersets.
4. **Exercise library** — searchable, filterable by muscle group & equipment, plus
   custom exercises.
5. **Workout history** — calendar view with streaks, per-workout summary (duration,
   total volume, PRs hit).

### Progress & motivation (v1)
6. **Per-exercise analytics** — estimated 1RM trend, best set, total volume charts,
   full history list.
7. **PR detection** — weight PR, rep PR, volume PR detected automatically with a
   purple-glow celebration moment.
8. **Titan Ranks** — gamified achievement system themed to the brand: ranks from
   Bronze → Iron → Spartan → Titan earned via consistency streaks and milestones.
9. **Muscle heat map** — front/back body silhouette shaded purple by weekly volume
   per muscle group.
10. **Dashboard** — this week at a glance: workouts done, volume, streak, next
    scheduled routine, recent PRs.

### Utilities (v1)
11. **Plate calculator** — given a target barbell weight, show plates per side.
12. **Body metrics** — bodyweight + measurements logged over time with trend chart.

### Later (not in v1 design)
- Cloud sync / accounts, social sharing, workout programs marketplace, wearable import.

## Platform

Mobile-first web app (PWA), single-user, offline-capable, data stored locally.
Design at 390×844 (iPhone-ish). Bottom tab navigation: Home, History, **Start Workout
(center, prominent)**, Progress, Profile.
