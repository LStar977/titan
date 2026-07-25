import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Backdrop } from "./Backdrop";
import { Phone } from "./Phone";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";
import { ScreenLogSet } from "../scenes/ScreenLogSet";
import { ScreenPR } from "../scenes/ScreenPR";
import { ScreenHeatMap } from "../scenes/ScreenHeatMap";
import { ScreenRanks } from "../scenes/ScreenRanks";

export const SEGMENT = 145;
export const STAGE_FRAMES = SEGMENT * 4;

type Seg = {
  eyebrow: string;
  line1: string;
  line2: string;
  Screen: React.FC<{ brand: Brand; frame: number }>;
};

const segments = (brand: Brand): Seg[] => [
  {
    eyebrow: "Built for the gym floor",
    line1: "LOG A SET",
    line2: "IN SECONDS",
    Screen: ScreenLogSet,
  },
  {
    eyebrow: "No spreadsheets, no math",
    line1: "IT SPOTS",
    line2: "EVERY PR",
    Screen: ScreenPR,
  },
  {
    eyebrow: "Know what you've hit",
    line1: "SEE YOUR",
    line2: "WHOLE BODY",
    Screen: ScreenHeatMap,
  },
  {
    eyebrow: "Earn every level",
    line1: brand.key === "valkyrie" ? "RISE FROM" : "CLIMB FROM",
    line2: `${brand.rankNames[0]} TO ${brand.rankNames[3]}`,
    Screen: ScreenRanks,
  },
];

/** Fades a value in at the start of a window and out at the end. */
const windowOpacity = (f: number, start: number, end: number, ramp = 12) =>
  interpolate(
    f,
    [start - 2, start + ramp, end - ramp, end],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

/** The feature tour: one persistent phone, four screens, four headlines. */
export const Stage: React.FC<{ brand: Brand }> = ({ brand }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const rise = spring({
    frame: frame - 4,
    fps,
    config: { damping: 26, stiffness: 90 },
  });
  const drift = interpolate(frame, [0, STAGE_FRAMES], [0, -46]);
  const segs = segments(brand);

  return (
    <AbsoluteFill>
      <Backdrop brand={brand} />

      {/* Headlines */}
      {segs.map((s, i) => {
        const start = i * SEGMENT;
        const op = windowOpacity(frame, start, start + SEGMENT, 14);
        const local = frame - start;
        const slide = interpolate(local, [0, 18], [30, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
        return (
          <AbsoluteFill
            key={i}
            style={{
              alignItems: "center",
              paddingTop: 122,
              opacity: op,
            }}
          >
            <div style={{ textAlign: "center", transform: `translateY(${slide}px)` }}>
              <div
                style={{
                  fontFamily: BARLOW,
                  fontWeight: 600,
                  fontSize: 25,
                  letterSpacing: 5.5,
                  textTransform: "uppercase",
                  color: brand.isLight ? "#F4C4D8" : brand.primaryBright,
                  marginBottom: 16,
                }}
              >
                {s.eyebrow}
              </div>
              <div
                style={{
                  fontFamily: CONDENSED,
                  fontWeight: 800,
                  fontSize: 96,
                  lineHeight: 0.94,
                  letterSpacing: 1,
                  color: "#FFFFFF",
                  textShadow: `0 6px 40px rgba(0,0,0,0.5)`,
                }}
              >
                {s.line1}
                <br />
                {s.line2}
              </div>
            </div>
          </AbsoluteFill>
        );
      })}

      {/* Phone */}
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "flex-start",
          paddingTop: 548,
          transform: `translateY(${interpolate(rise, [0, 1], [180, 0]) + drift}px)`,
          opacity: rise,
        }}
      >
        <Phone brand={brand}>
          {segs.map((s, i) => {
            const start = i * SEGMENT;
            const op = windowOpacity(frame, start, start + SEGMENT, 11);
            if (op <= 0.001) return null;
            const S = s.Screen;
            return (
              <AbsoluteFill key={i} style={{ opacity: op }}>
                <S brand={brand} frame={frame - start} />
              </AbsoluteFill>
            );
          })}
        </Phone>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
