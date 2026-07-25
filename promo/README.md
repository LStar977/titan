# TITAN / VALKYRIE promo videos

Promo videos built with [Remotion](https://remotion.dev) — the video is defined
in React, so the app's real palette (`Titan/Brand.swift`), real Barlow fonts
(`Titan/Fonts/`), and real app icons (`Titan/Assets.xcassets/`) are used
directly. One definition renders both brands, the same way the two app targets
share one codebase.

Finished files live in `renders/`:

| File | Brand | Size |
| --- | --- | --- |
| `renders/titan-promo.mp4` | TITAN (dark purple) | 1080×1920, 26s, 30fps |
| `renders/valkyrie-promo.mp4` | VALKYRIE (pink) | 1080×1920, 26s, 30fps |

1080×1920 vertical suits App Store previews, Instagram Reels, TikTok, and
YouTube Shorts.

## Structure

```
src/
  brand.ts                 palettes + copy for both brands
  fonts.ts                 loads Barlow from public/fonts
  Promo.tsx                timeline: intro → feature tour → outro
  Root.tsx                 registers TitanPromo and ValkyriePromo
  components/
    Backdrop.tsx           stage glow + vignette
    Phone.tsx              device shell
    Stage.tsx              persistent phone, four headlines, four screens
    ui.tsx                 Card / Label / Display / Hexagon / PRBadge
  scenes/
    Intro.tsx              wordmark cold open
    ScreenLogSet.tsx       logging a set, ghost values, rest timer
    ScreenPR.tsx           estimated 1RM chart, PR detection
    ScreenHeatMap.tsx      muscle heat map, volume split
    ScreenRanks.tsx        rank ladder and XP
    Outro.tsx              icon, wordmark, call to action
```

## Editing

```sh
cd promo
npm install
npm run studio        # live preview at localhost:3000, scrub the timeline
```

The studio hot-reloads, so tweaking copy in `src/brand.ts` or a scene shows up
instantly. Text most likely to need changing:

- `tagline`, `closingLine`, `storeName` in `src/brand.ts`
- `"Coming soon to the App Store"` in `src/scenes/Outro.tsx` — swap for
  "Now on the App Store" at launch
- headlines and eyebrows in the `segments()` array in `src/components/Stage.tsx`

## Re-rendering

```sh
npm run render            # TITAN  → out/titan-promo.mp4
npm run render:valkyrie   # VALKYRIE → out/valkyrie-promo.mp4
```

Copy the result into `renders/` to update the committed version. On Linux CI you
may need `--browser-executable=<path to chrome-headless-shell>`; on macOS
Remotion finds Chrome by itself.

## Licence note

Remotion is free for individuals and companies of three people or fewer; larger
companies need a paid licence. See https://remotion.dev/license.

The videos are silent. Add music in any editor, or with Remotion's `<Audio>` tag
— use a track you have rights to, since App Store previews are reviewed.
