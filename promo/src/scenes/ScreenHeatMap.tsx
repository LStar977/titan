import React from "react";
import { interpolate, interpolateColors } from "remotion";
import { Screen } from "../components/Phone";
import { Card, Display, Label } from "../components/ui";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";

type Pill = {
  x: number;
  y: number;
  w: number;
  h: number;
  rx: number;
  heat: number;
};

/** Front-view body built from pills, mirroring the app's BodyHeatMap. */
const BODY: Pill[] = [
  { x: 68, y: 4, w: 20, h: 24, rx: 10, heat: 0 }, // head
  { x: 70, y: 30, w: 16, h: 8, rx: 4, heat: 0.35 }, // neck
  { x: 40, y: 40, w: 22, h: 20, rx: 10, heat: 0.85 }, // L delt
  { x: 94, y: 40, w: 22, h: 20, rx: 10, heat: 0.85 }, // R delt
  { x: 64, y: 42, w: 13, h: 26, rx: 6, heat: 1.0 }, // L chest
  { x: 79, y: 42, w: 13, h: 26, rx: 6, heat: 1.0 }, // R chest
  { x: 34, y: 62, w: 17, h: 32, rx: 8, heat: 0.4 }, // L bicep
  { x: 105, y: 62, w: 17, h: 32, rx: 8, heat: 0.4 }, // R bicep
  { x: 29, y: 96, w: 15, h: 30, rx: 7, heat: 0.2 }, // L forearm
  { x: 112, y: 96, w: 15, h: 30, rx: 7, heat: 0.2 }, // R forearm
  { x: 66, y: 70, w: 24, h: 38, rx: 8, heat: 0.55 }, // abs
  { x: 58, y: 110, w: 18, h: 46, rx: 9, heat: 0.7 }, // L quad
  { x: 80, y: 110, w: 18, h: 46, rx: 9, heat: 0.7 }, // R quad
  { x: 60, y: 160, w: 15, h: 36, rx: 7, heat: 0.25 }, // L calf
  { x: 81, y: 160, w: 15, h: 36, rx: 7, heat: 0.25 }, // R calf
];

const VOLUME = [
  { name: "Chest", value: "24.6k", pct: 1.0 },
  { name: "Shoulders", value: "18.2k", pct: 0.74 },
  { name: "Quads", value: "15.9k", pct: 0.64 },
  { name: "Back", value: "11.4k", pct: 0.46 },
];

/** Screen 3 — the muscle heat map and weekly volume split. */
export const ScreenHeatMap: React.FC<{ brand: Brand; frame: number }> = ({
  brand,
  frame,
}) => {
  return (
    <Screen>
      <Display color={brand.textMain} size={44}>
        PROGRESS
      </Display>

      {/* Period picker */}
      <div style={{ display: "flex", gap: 8, marginTop: 18 }}>
        {["Week", "Month", "All time"].map((p, i) => (
          <div
            key={p}
            style={{
              flex: 1,
              textAlign: "center",
              padding: "11px 0",
              borderRadius: 13,
              background: i === 0 ? brand.primary : brand.surface,
              border: `1.5px solid ${i === 0 ? brand.primary : brand.hairline}`,
              fontFamily: BARLOW,
              fontWeight: 600,
              fontSize: 15.5,
              letterSpacing: 1.4,
              color: i === 0 ? "#FFFFFF" : brand.textDim,
            }}
          >
            {p}
          </div>
        ))}
      </div>

      <Card brand={brand} radius={26} style={{ marginTop: 16, padding: 22 }}>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <Label color={brand.textDim} size={13} kerning={2}>
            Muscle heat map
          </Label>
          <div
            style={{
              display: "flex",
              borderRadius: 10,
              overflow: "hidden",
              border: `1.5px solid ${brand.hairline}`,
            }}
          >
            {["M", "F"].map((g, i) => (
              <div
                key={g}
                style={{
                  padding: "6px 15px",
                  background:
                    (brand.key === "valkyrie" ? 1 : 0) === i
                      ? brand.primary
                      : "transparent",
                  color:
                    (brand.key === "valkyrie" ? 1 : 0) === i
                      ? "#FFFFFF"
                      : brand.textDim,
                  fontFamily: BARLOW,
                  fontWeight: 700,
                  fontSize: 14,
                }}
              >
                {g}
              </div>
            ))}
          </div>
        </div>

        <div
          style={{
            display: "flex",
            justifyContent: "center",
            marginTop: 10,
            marginBottom: 4,
          }}
        >
          <svg width={310} height={400} viewBox="0 0 156 200">
            {BODY.map((p, i) => {
              const start = 10 + i * 3.5;
              const t = interpolate(frame, [start, start + 16], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              });
              const fill = interpolateColors(
                t * p.heat,
                [0, 0.5, 1],
                [brand.heatBody, brand.primaryDeep, brand.primaryBright],
              );
              return (
                <rect
                  key={i}
                  x={p.x}
                  y={p.y}
                  width={p.w}
                  height={p.h}
                  rx={p.rx}
                  fill={fill}
                  style={{
                    filter:
                      p.heat > 0.8 && t > 0.5
                        ? `drop-shadow(0 0 6px ${brand.primary}bb)`
                        : "none",
                  }}
                />
              );
            })}
          </svg>
        </div>

        {/* Legend */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            justifyContent: "center",
          }}
        >
          <Label color={brand.textFaint} size={12} kerning={1.6}>
            Less
          </Label>
          <div
            style={{
              width: 190,
              height: 9,
              borderRadius: 5,
              background: `linear-gradient(90deg, ${brand.heatBody}, ${brand.primaryDeep}, ${brand.primaryBright})`,
            }}
          />
          <Label color={brand.textFaint} size={12} kerning={1.6}>
            More
          </Label>
        </div>
      </Card>

      {/* Volume split */}
      <Card brand={brand} radius={24} style={{ marginTop: 14, padding: 20 }}>
        <Label
          color={brand.textDim}
          size={13}
          kerning={2}
          style={{ marginBottom: 12 }}
        >
          Volume by muscle
        </Label>
        {VOLUME.map((v, i) => {
          const start = 44 + i * 7;
          const grow = interpolate(frame, [start, start + 22], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <div key={v.name} style={{ marginTop: i === 0 ? 0 : 13 }}>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  marginBottom: 6,
                }}
              >
                <span
                  style={{
                    fontFamily: BARLOW,
                    fontWeight: 600,
                    fontSize: 16,
                    color: brand.textSoft,
                  }}
                >
                  {v.name}
                </span>
                <span
                  style={{
                    fontFamily: CONDENSED,
                    fontWeight: 700,
                    fontSize: 20,
                    color: brand.textMain,
                  }}
                >
                  {v.value} lb
                </span>
              </div>
              <div
                style={{
                  height: 10,
                  borderRadius: 5,
                  background: brand.isLight
                    ? "rgba(0,0,0,0.05)"
                    : "rgba(255,255,255,0.05)",
                  overflow: "hidden",
                }}
              >
                <div
                  style={{
                    height: "100%",
                    width: `${v.pct * grow * 100}%`,
                    borderRadius: 5,
                    background: `linear-gradient(90deg, ${brand.primaryDeep}, ${brand.primaryBright})`,
                  }}
                />
              </div>
            </div>
          );
        })}
      </Card>

      {/* Week summary */}
      <div style={{ display: "flex", gap: 12, marginTop: 14 }}>
        {[
          { label: "Workouts", value: "12" },
          { label: "Volume", value: "84k" },
          { label: "Streak", value: "5w" },
        ].map((s, i) => {
          const op = interpolate(frame, [70 + i * 6, 86 + i * 6], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <Card
              key={s.label}
              brand={brand}
              radius={20}
              style={{ flex: 1, padding: "16px 14px", opacity: op }}
            >
              <Label color={brand.textDim} size={12.5} kerning={2}>
                {s.label}
              </Label>
              <div
                style={{
                  fontFamily: CONDENSED,
                  fontWeight: 700,
                  fontSize: 40,
                  color: brand.textMain,
                  marginTop: 4,
                }}
              >
                {s.value}
              </div>
            </Card>
          );
        })}
      </div>
    </Screen>
  );
};
