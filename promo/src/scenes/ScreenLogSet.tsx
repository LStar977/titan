import React from "react";
import { AbsoluteFill, interpolate, spring, useVideoConfig } from "remotion";
import { Screen } from "../components/Phone";
import { Card, Display, Label } from "../components/ui";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";

const fmtClock = (total: number) => {
  const s = Math.max(0, Math.floor(total));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
};

type Row = {
  set: number;
  weight: string;
  reps: string;
  done: boolean;
};

const DONE_ROWS: Row[] = [
  { set: 1, weight: "135", reps: "12", done: true },
  { set: 2, weight: "185", reps: "10", done: true },
];

/** Screen 1 — logging a set, with ghost values and the auto rest timer. */
export const ScreenLogSet: React.FC<{ brand: Brand; frame: number }> = ({
  brand,
  frame,
}) => {
  const { fps } = useVideoConfig();

  // Ghost values firm up, then the set is checked off.
  const ghostSolid = interpolate(frame, [26, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const checked = frame >= 52;
  const checkPop = spring({
    frame: frame - 52,
    fps,
    config: { damping: 11, stiffness: 190 },
  });
  const tap = interpolate(frame, [46, 62], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const restIn = spring({
    frame: frame - 60,
    fps,
    config: { damping: 22, stiffness: 130 },
  });
  const restSeconds = 120 - Math.max(0, (frame - 60) / fps) * 2.2;
  const restRemaining = Math.max(0, Math.min(1, restSeconds / 120));

  const elapsed = 1471 + Math.floor(frame / fps);

  const rowTint = interpolate(checkPop, [0, 1], [0, 1]);

  return (
    <Screen>
      {/* Header */}
      <div
        style={{
          display: "flex",
          alignItems: "baseline",
          justifyContent: "space-between",
          marginBottom: 4,
        }}
      >
        <Display color={brand.textMain} size={40} kerning={0.5}>
          PUSH DAY
        </Display>
        <Display color={brand.primaryBright} size={34} weight={700}>
          {fmtClock(elapsed)}
        </Display>
      </div>
      <Label color={brand.textDim} size={14} kerning={2.2}>
        Exercise 3 of 5 · 14 sets
      </Label>

      {/* Exercise card */}
      <Card brand={brand} radius={26} style={{ marginTop: 26, padding: 24 }}>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <div>
            <Display color={brand.textMain} size={34}>
              BENCH PRESS
            </Display>
            <Label
              color={brand.textDim}
              size={13.5}
              kerning={2}
              style={{ marginTop: 5 }}
            >
              Barbell · Chest
            </Label>
          </div>
          <div
            style={{
              color: brand.textFaint,
              fontSize: 30,
              letterSpacing: 2,
              lineHeight: 0.6,
              paddingBottom: 8,
            }}
          >
            •••
          </div>
        </div>

        {/* Column headers */}
        <div
          style={{
            display: "flex",
            marginTop: 24,
            paddingBottom: 10,
            borderBottom: `1.5px solid ${brand.hairline}`,
          }}
        >
          <ColHead brand={brand} w={62} align="left">
            Set
          </ColHead>
          <ColHead brand={brand} w={150}>
            lbs
          </ColHead>
          <ColHead brand={brand} w={150}>
            Reps
          </ColHead>
          <div style={{ flex: 1 }} />
        </div>

        {DONE_ROWS.map((r) => (
          <SetRow key={r.set} brand={brand} row={r} solid={1} checked tint={0} />
        ))}

        <SetRow
          brand={brand}
          row={{ set: 3, weight: "205", reps: "8", done: false }}
          solid={ghostSolid}
          checked={checked}
          tint={rowTint}
          pop={checkPop}
          tapRipple={tap}
        />
        <SetRow
          brand={brand}
          row={{ set: 4, weight: "205", reps: "8", done: false }}
          solid={0}
          checked={false}
          tint={0}
        />

        {/* Ghost-value hint */}
        <div
          style={{
            marginTop: 18,
            display: "flex",
            alignItems: "center",
            gap: 10,
            opacity: interpolate(frame, [8, 24], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          <div
            style={{
              width: 8,
              height: 8,
              borderRadius: 4,
              background: brand.primary,
            }}
          />
          <div
            style={{
              fontFamily: BARLOW,
              fontWeight: 500,
              fontSize: 15,
              color: brand.textDim,
            }}
          >
            Pre-filled from last session
          </div>
        </div>
      </Card>

      {/* Next exercise, waiting */}
      <Card brand={brand} radius={26} style={{ marginTop: 16, padding: 22 }}>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <div>
            <Display color={brand.textSoft} size={30}>
              INCLINE DB PRESS
            </Display>
            <Label
              color={brand.textFaint}
              size={13}
              kerning={2}
              style={{ marginTop: 5 }}
            >
              Dumbbell · Chest
            </Label>
          </div>
          <div
            style={{
              fontFamily: BARLOW,
              fontWeight: 600,
              fontSize: 15,
              color: brand.textFaint,
              letterSpacing: 1.4,
            }}
          >
            3 SETS
          </div>
        </div>
        <div style={{ display: "flex", gap: 10, marginTop: 16 }}>
          {["60 × 10", "60 × 10", "55 × 12"].map((s, i) => (
            <div
              key={i}
              style={{
                flex: 1,
                textAlign: "center",
                padding: "11px 0",
                borderRadius: 12,
                background: brand.surface2,
                fontFamily: CONDENSED,
                fontWeight: 700,
                fontSize: 24,
                color: brand.textFaint,
              }}
            >
              {s}
            </div>
          ))}
        </div>
      </Card>

      {/* Add exercise */}
      <div
        style={{
          marginTop: 16,
          borderRadius: 18,
          border: `2px dashed ${brand.outline}`,
          padding: "18px 0",
          textAlign: "center",
          fontFamily: BARLOW,
          fontWeight: 600,
          fontSize: 17,
          letterSpacing: 2,
          color: brand.textDim,
        }}
      >
        + ADD EXERCISE
      </div>

      {/* Rest timer bar */}
      <div
        style={{
          position: "absolute",
          left: 30,
          right: 30,
          bottom: 62,
          transform: `translateY(${interpolate(restIn, [0, 1], [190, 0])}px)`,
          opacity: restIn,
        }}
      >
        <div
          style={{
            background: brand.surface2,
            borderRadius: 24,
            border: `1.5px solid ${brand.primary}55`,
            padding: "20px 24px",
            boxShadow: `0 20px 50px rgba(0,0,0,${brand.isLight ? 0.12 : 0.5})`,
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
            }}
          >
            <Label color={brand.textDim} size={14} kerning={2.4}>
              Rest
            </Label>
            <Display color={brand.primaryBright} size={40} weight={700}>
              {fmtClock(restSeconds)}
            </Display>
          </div>
          <div
            style={{
              height: 7,
              borderRadius: 4,
              background: brand.isLight
                ? "rgba(0,0,0,0.07)"
                : "rgba(255,255,255,0.07)",
              marginTop: 14,
              overflow: "hidden",
            }}
          >
            <div
              style={{
                height: "100%",
                width: `${restRemaining * 100}%`,
                borderRadius: 4,
                background: `linear-gradient(90deg, ${brand.primaryDeep}, ${brand.primaryBright})`,
              }}
            />
          </div>
        </div>
      </div>
    </Screen>
  );
};

const ColHead: React.FC<{
  brand: Brand;
  w: number;
  align?: "left" | "center";
  children: React.ReactNode;
}> = ({ brand, w, align = "center", children }) => (
  <div style={{ width: w, textAlign: align }}>
    <Label color={brand.textFaint} size={12.5} kerning={2}>
      {children}
    </Label>
  </div>
);

const SetRow: React.FC<{
  brand: Brand;
  row: Row;
  solid: number;
  checked: boolean;
  tint: number;
  pop?: number;
  tapRipple?: number;
}> = ({ brand, row, solid, checked, tint, pop = 1, tapRipple }) => {
  const valueColor = checked
    ? brand.textMain
    : `rgba(${brand.isLight ? "36,26,32" : "237,237,244"}, ${interpolate(
        solid,
        [0, 1],
        [0.3, 1],
      )})`;

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        paddingTop: 15,
        paddingBottom: 15,
        borderBottom: `1px solid ${brand.hairline}`,
        background:
          tint > 0
            ? `linear-gradient(90deg, ${brand.primary}${Math.round(tint * 18)
                .toString(16)
                .padStart(2, "0")}, transparent 65%)`
            : "transparent",
        borderRadius: 10,
        position: "relative",
      }}
    >
      <div style={{ width: 62 }}>
        <div
          style={{
            width: 38,
            height: 38,
            borderRadius: 12,
            background: brand.surface2,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontFamily: CONDENSED,
            fontWeight: 700,
            fontSize: 21,
            color: brand.textSoft,
          }}
        >
          {row.set}
        </div>
      </div>

      <div style={{ width: 150, textAlign: "center" }}>
        <span
          style={{
            fontFamily: CONDENSED,
            fontWeight: 700,
            fontSize: 34,
            color: valueColor,
          }}
        >
          {row.weight}
        </span>
      </div>
      <div style={{ width: 150, textAlign: "center" }}>
        <span
          style={{
            fontFamily: CONDENSED,
            fontWeight: 700,
            fontSize: 34,
            color: valueColor,
          }}
        >
          {row.reps}
        </span>
      </div>

      <div
        style={{
          flex: 1,
          display: "flex",
          justifyContent: "flex-end",
          position: "relative",
        }}
      >
        {tapRipple !== undefined && tapRipple > 0 && tapRipple < 1 ? (
          <div
            style={{
              position: "absolute",
              right: -4,
              top: "50%",
              width: 96,
              height: 96,
              marginTop: -48,
              borderRadius: 48,
              border: `3px solid ${brand.primary}`,
              opacity: 1 - tapRipple,
              transform: `scale(${0.4 + tapRipple * 0.9})`,
            }}
          />
        ) : null}
        <div
          style={{
            width: 46,
            height: 46,
            borderRadius: 14,
            background: checked
              ? `linear-gradient(135deg, ${brand.primaryMid}, ${brand.primary})`
              : "transparent",
            border: checked ? "none" : `2px solid ${brand.outline}`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            transform: `scale(${checked ? 0.9 + pop * 0.1 + Math.sin(pop * Math.PI) * 0.12 : 1})`,
            boxShadow: checked ? `0 0 26px ${brand.primary}66` : "none",
          }}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path
              d="M4 12.5L9.5 18L20 6.5"
              stroke={checked ? "#FFFFFF" : brand.textFaint}
              strokeWidth="3.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
      </div>
    </div>
  );
};
