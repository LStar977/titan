import React from "react";
import { interpolate, spring, useVideoConfig } from "remotion";
import { Screen } from "../components/Phone";
import { Card, Display, Hexagon, Label } from "../components/ui";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";

/** Screen 4 — the rank ladder and XP earned for showing up. */
export const ScreenRanks: React.FC<{ brand: Brand; frame: number }> = ({
  brand,
  frame,
}) => {
  const { fps } = useVideoConfig();

  const bigPop = spring({
    frame: frame - 6,
    fps,
    config: { damping: 12, stiffness: 150 },
  });
  const xp = Math.round(
    interpolate(frame, [24, 74], [4180, 6420], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }),
  );
  const barFill = interpolate(frame, [24, 74], [0.465, 0.713], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const pulse = 1 + Math.sin((frame / 22) * Math.PI) * 0.02;

  return (
    <Screen>
      <Display color={brand.textMain} size={44}>
        {brand.key === "valkyrie" ? "THE ASCENT" : "THE CLIMB"}
      </Display>
      <Label
        color={brand.textDim}
        size={14}
        kerning={2.2}
        style={{ marginTop: 6 }}
      >
        Level 7 of 12
      </Label>

      {/* Current rank */}
      <Card
        brand={brand}
        radius={28}
        border={`${brand.primary}44`}
        style={{
          marginTop: 24,
          padding: "34px 24px 28px",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
        }}
      >
        <div
          style={{
            transform: `scale(${bigPop * pulse})`,
            filter: `drop-shadow(0 0 34px ${brand.primary}88)`,
          }}
        >
          <Hexagon
            size={196}
            fill={`linear-gradient(150deg, ${brand.primaryDeep}, ${brand.primary})`}
            border={brand.glow}
          >
            <div style={{ textAlign: "center" }}>
              <div
                style={{
                  fontFamily: CONDENSED,
                  fontWeight: 800,
                  fontSize: 64,
                  color: "#FFFFFF",
                  lineHeight: 1,
                }}
              >
                VII
              </div>
            </div>
          </Hexagon>
        </div>

        <div
          style={{
            fontFamily: CONDENSED,
            fontWeight: 800,
            fontSize: 46,
            letterSpacing: 2,
            color: brand.textMain,
            marginTop: 18,
          }}
        >
          {brand.rankNames[2]}
        </div>

        {/* XP bar */}
        <div style={{ width: "100%", marginTop: 22 }}>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              marginBottom: 8,
            }}
          >
            <Label color={brand.textDim} size={13} kerning={1.8}>
              {xp.toLocaleString()} XP
            </Label>
            <Label color={brand.textFaint} size={13} kerning={1.8}>
              9,000 to {brand.rankNames[3]}
            </Label>
          </div>
          <div
            style={{
              height: 14,
              borderRadius: 7,
              background: brand.isLight
                ? "rgba(0,0,0,0.06)"
                : "rgba(255,255,255,0.06)",
              overflow: "hidden",
            }}
          >
            <div
              style={{
                height: "100%",
                width: `${barFill * 100}%`,
                borderRadius: 7,
                background: `linear-gradient(90deg, ${brand.primaryDeep}, ${brand.glow})`,
                boxShadow: `0 0 20px ${brand.primary}aa`,
              }}
            />
          </div>
        </div>
      </Card>

      {/* Tier ladder */}
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          marginTop: 26,
          paddingLeft: 4,
          paddingRight: 4,
        }}
      >
        {brand.rankNames.map((name, i) => {
          const done = i < 2;
          const current = i === 2;
          const pop = spring({
            frame: frame - (34 + i * 6),
            fps,
            config: { damping: 14, stiffness: 160 },
          });
          return (
            <div
              key={name}
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 10,
                opacity: pop,
                transform: `translateY(${interpolate(pop, [0, 1], [16, 0])}px)`,
              }}
            >
              <Hexagon
                size={92}
                fill={
                  current
                    ? `linear-gradient(150deg, ${brand.primaryDeep}, ${brand.primary})`
                    : done
                      ? brand.surface3
                      : brand.surface
                }
                border={
                  current
                    ? brand.glow
                    : done
                      ? brand.outline
                      : brand.hairline
                }
              >
                {done ? (
                  <svg width="30" height="30" viewBox="0 0 24 24" fill="none">
                    <path
                      d="M4 12.5L9.5 18L20 6.5"
                      stroke={brand.textSoft}
                      strokeWidth="3"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                ) : current ? (
                  <div
                    style={{
                      fontFamily: CONDENSED,
                      fontWeight: 800,
                      fontSize: 30,
                      color: "#FFFFFF",
                    }}
                  >
                    7
                  </div>
                ) : (
                  <div style={{ fontSize: 26, opacity: 0.5 }}>🔒</div>
                )}
              </Hexagon>
              <div
                style={{
                  fontFamily: BARLOW,
                  fontWeight: 700,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color: current ? brand.textMain : brand.textFaint,
                }}
              >
                {name}
              </div>
            </div>
          );
        })}
      </div>

      {/* XP earned toast */}
      <div
        style={{
          marginTop: 26,
          background: brand.surface,
          border: `1.5px solid ${brand.hairline}`,
          borderRadius: 20,
          padding: "18px 22px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          opacity: interpolate(frame, [66, 84], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        <div
          style={{
            fontFamily: BARLOW,
            fontWeight: 600,
            fontSize: 17,
            color: brand.textSoft,
          }}
        >
          Push Day · 18 sets · 1 {brand.prWord}
        </div>
        <div
          style={{
            fontFamily: CONDENSED,
            fontWeight: 800,
            fontSize: 28,
            color: brand.success,
          }}
        >
          +395 XP
        </div>
      </div>

      {/* Recent records */}
      <Card brand={brand} radius={24} style={{ marginTop: 14, padding: 20 }}>
        <Label
          color={brand.textDim}
          size={13}
          kerning={2}
          style={{ marginBottom: 4 }}
        >
          Recent {brand.recordsWord}
        </Label>
        {[
          { name: "Bench Press", detail: "205 lb × 8", when: "Today" },
          { name: "Back Squat", detail: "285 lb × 5", when: "3d ago" },
          { name: "Deadlift", detail: "315 lb × 3", when: "6d ago" },
        ].map((r, i) => {
          const op = interpolate(frame, [78 + i * 8, 94 + i * 8], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <div
              key={r.name}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                paddingTop: 12,
                paddingBottom: 12,
                borderTop: i === 0 ? "none" : `1px solid ${brand.hairline}`,
                opacity: op,
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <div style={{ fontSize: 22 }}>🔥</div>
                <div>
                  <div
                    style={{
                      fontFamily: BARLOW,
                      fontWeight: 600,
                      fontSize: 17,
                      color: brand.textMain,
                    }}
                  >
                    {r.name}
                  </div>
                  <div
                    style={{
                      fontFamily: CONDENSED,
                      fontWeight: 700,
                      fontSize: 21,
                      color: brand.primaryBright,
                      marginTop: 1,
                    }}
                  >
                    {r.detail}
                  </div>
                </div>
              </div>
              <span
                style={{
                  fontFamily: BARLOW,
                  fontWeight: 500,
                  fontSize: 15,
                  color: brand.textFaint,
                }}
              >
                {r.when}
              </span>
            </div>
          );
        })}
      </Card>
    </Screen>
  );
};
