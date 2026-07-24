# TITΛN — Strength Logger

A native iOS strength-training tracker. Dark-only, purple-on-black, built to match the
Claude Design handoff (`DESIGN_BRIEF.md` has the full feature scope).

**This repo builds two apps from one codebase:**

| Target | Brand | Theme | Bundle ID |
|---|---|---|---|
| `Titan` | TITΛN — dark, mythic (Bronze → Titan ranks) | Dark purple/black | `com.lancemorrison.titan` |
| `Valkyrie` | VALKYRIE — bright, empowering (Ember → Immortal ranks) | Light blush/pink | `com.lancemorrison.valkyrie` |

All branding (palette, wordmark, copy, rank ladder, default body model, flagship
program) routes through `Titan/Brand.swift`, switched by the `VALKYRIE` compilation
condition on the Valkyrie target. Every feature lands in both apps automatically —
pick the scheme in Xcode to build either one.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-8B5CF6) ![Stack](https://img.shields.io/badge/SwiftUI%20%2B%20SwiftData-131320)

## Features

- **Workout logging** — sets × reps × weight with ghost values pre-filled from your last
  session; one tap on ✓ repeats it. Set types: warm-up / working / failure / drop.
- **PR detection** — every completed set is checked against your all-time estimated 1RM
  (Epley); beating it ignites the violet-glow PR row + haptic.
- **Auto rest timer** — starts on set completion, docks at the bottom with +30s / Skip.
- **Routines** — 4 starter templates seeded (Push A/B, Pull A, Legs), full editor with
  reorder, per-exercise sets/rep-range/rest, and superset grouping.
- **Exercise library** — ~60 seeded exercises, searchable, filterable by muscle and
  equipment, plus custom exercises.
- **History** — month calendar with trained days, streaks, and per-day summaries.
- **Exercise detail** — e1RM trend, weekly volume bars, full session history.
- **Progress** — front/back muscle heat map + volume-by-muscle bars (week/month/year).
- **Titan Ranks** — XP from sets, PRs, and finished workouts climbs Bronze → Iron →
  Spartan → Titan (3 tiers each).
- **Plate calculator** — target weight → plates per side, with bar options.
- **Body metrics** — bodyweight sparkline + chest/arm/waist measurements.
- **Supplements** — one-tap serving logging (creatine, protein, custom), daily
  totals and a 7-day history. Quick-log card on Home, full page from Profile.

Everything is stored on-device with SwiftData. No account, no network.

## Running it

1. Open `Titan.xcodeproj` in **Xcode 16 or newer** on macOS.
2. Select the **Titan** scheme and an iPhone simulator (iOS 17+).
3. **⌘R**.

To run on a physical iPhone, set your development team under
*Target → Signing & Capabilities* first.

## Project layout

```
Titan/
├── TitanApp.swift          # entry point, SwiftData container, font registration
├── AppState.swift          # observable app state (active workout, rest timer, tab)
├── Theme.swift             # design tokens: colors, Barlow fonts, shared styles
├── Models/
│   ├── Models.swift        # SwiftData models (Exercise, Routine, Workout, Set…)
│   ├── Stats.swift         # e1RM, volume, streaks, PRs, Titan rank system
│   └── SeedData.swift      # exercise library + starter routines, workout builder
├── Views/                  # one file per screen + shared components
├── Fonts/                  # Barlow & Barlow Condensed (OFL licensed)
└── Assets.xcassets         # app icon, accent color
```

Fonts are registered at runtime (`CTFontManagerRegisterFontsForURL`), so no Info.plist
font keys are needed.
