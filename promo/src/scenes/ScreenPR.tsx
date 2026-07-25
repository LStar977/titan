import React from "react";
import { interpolate, spring, useVideoConfig } from "remotion";
import { Screen } from "../components/Phone";
import { Card, Display, Label, PRBadge } from "../components/ui";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";

const SERIES = [212, 218, 215, 228, 236, 231, 244, 252, 249, 258, 262, 267];

/** Screen 2 — estimated 1RM climbing, and a PR the app caught on its own. */
export const ScreenPR: React.FC<{ brand: Brand; frame: number }> = ({
  brand,
  frame,
}) => {
  const { fps } = useVideoConfig();

  const count = Math.round(
    interpolate(frame, [10, 48], [231, 267], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }),
  );
  const draw = interpolate(frame, [16, 74], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const badgePop = spring({
    frame: frame - 54,
    fps,
    config: { damping: 10, stiffness: 170 },
  });
  const bannerIn = spring({
    frame: frame - 62,
    fps,
    config: { damping: 20, stiffness: 120 },
  });

  const W = 530;
  const H = 292;
  const min = Math.min(...SERIES) - 10;
  const max = Math.max(...SERIES) + 8;
  const pts = SERIES.map((v, i) => {
    const x = (i / (SERIES.length - 1)) * W;
    const y = H - ((v - min) / (max - min)) * H;
    return [x, y] as const;
  });
  const line = pts.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x} ${y}`).join(" ");
  const area = `${line} L${W} ${H} L0 ${H} Z`;
  const last = pts[pts.length - 1];
  const dotVisible = draw > 0.985;

  return (
    <Screen>
      <Display color={brand.textMain} size={44}>
        BENCH PRESS
      </Display>
      <Label
        color={brand.textDim}
        size={14}
        kerning={2.2}
        style={{ marginTop: 6 }}
      >
        Barbell · Chest · 18 sessions
      </Label>

      {/* Stat row */}
      <div style={{ display: "flex", gap: 12, marginTop: 26 }}>
        <Card
          brand={brand}
          radius={20}
          border={`${brand.glow}55`}
          style={{ flex: 1.25, padding: "18px 16px" }}
        >
          <Label color={brand.glow} size={12.5} kerning={2}>
            Est. 1RM
          </Label>
          <div
            style={{
              display: "flex",
              alignItems: "baseline",
              gap: 4,
              marginTop: 6,
            }}
          >
            <span
              style={{
                fontFamily: CONDENSED,
                fontWeight: 700,
                fontSize: 52,
                color: brand.glow,
                textShadow: `0 0 26px ${brand.glow}88`,
              }}
            >
              {count}
            </span>
            <span
              style={{
                fontFamily: CONDENSED,
                fontWeight: 700,
                fontSize: 24,
                color: brand.textDim,
              }}
            >
              lb
            </span>
          </div>
        </Card>
        <SmallStat brand={brand} label="Best set" value="205×8" />
        <SmallStat brand={brand} label="Lifetime" value="284k" />
      </div>

      {/* Chart */}
      <Card brand={brand} radius={24} style={{ marginTop: 16, padding: 22 }}>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
          }}
        >
          <Label color={brand.textDim} size={13} kerning={2}>
            Estimated 1RM
          </Label>
          <Label color={brand.textFaint} size={13} kerning={1.4}>
            Last 12 sessions
          </Label>
        </div>

        <svg
          width={W}
          height={H}
          viewBox={`0 0 ${W} ${H}`}
          style={{ marginTop: 16, overflow: "visible" }}
        >
          <defs>
            <linearGradient id="areaFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={brand.primary} stopOpacity="0.42" />
              <stop offset="100%" stopColor={brand.primary} stopOpacity="0" />
            </linearGradient>
            <linearGradient id="lineStroke" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor={brand.primaryMid} />
              <stop offset="100%" stopColor={brand.glow} />
            </linearGradient>
          </defs>

          {[0.25, 0.5, 0.75].map((g) => (
            <line
              key={g}
              x1={0}
              x2={W}
              y1={H * g}
              y2={H * g}
              stroke={brand.hairline}
              strokeWidth={1.5}
            />
          ))}

          <path d={area} fill="url(#areaFill)" opacity={draw > 0.1 ? draw : 0} />
          <path
            d={line}
            fill="none"
            stroke="url(#lineStroke)"
            strokeWidth={5}
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={1 - draw}
          />
          {dotVisible ? (
            <>
              <circle
                cx={last[0]}
                cy={last[1]}
                r={16 + badgePop * 8}
                fill={brand.primary}
                opacity={0.25 * (1 - Math.min(1, badgePop))}
              />
              <circle
                cx={last[0]}
                cy={last[1]}
                r={9}
                fill={brand.glow}
                stroke={brand.surface}
                strokeWidth={4}
              />
            </>
          ) : null}
        </svg>

        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            marginTop: 14,
          }}
        >
          <Label color={brand.textFaint} size={12.5} kerning={1.4}>
            Mar 4
          </Label>
          <div style={{ opacity: Math.min(1, badgePop * 1.4) }}>
            <PRBadge brand={brand} scale={1.15} />
          </div>
        </div>
      </Card>

      {/* PR banner */}
      <div
        style={{
          marginTop: 20,
          opacity: bannerIn,
          transform: `translateY(${interpolate(bannerIn, [0, 1], [26, 0])}px)`,
          background: `linear-gradient(100deg, ${brand.primaryDeep}, ${brand.primary})`,
          borderRadius: 22,
          padding: "22px 24px",
          display: "flex",
          alignItems: "center",
          gap: 16,
          boxShadow: `0 18px 46px ${brand.primary}55`,
        }}
      >
        <div style={{ fontSize: 40, lineHeight: 1 }}>🔥</div>
        <div>
          <div
            style={{
              fontFamily: CONDENSED,
              fontWeight: 800,
              fontSize: 30,
              color: "#FFFFFF",
              letterSpacing: 0.6,
            }}
          >
            NEW PERSONAL RECORD
          </div>
          <div
            style={{
              fontFamily: BARLOW,
              fontWeight: 500,
              fontSize: 17,
              color: "rgba(255,255,255,0.82)",
              marginTop: 2,
            }}
          >
            205 lb × 8 · beat your best by 9 lb
          </div>
        </div>
      </div>

      {/* Session history */}
      <Card brand={brand} radius={24} style={{ marginTop: 16, padding: 20 }}>
        <Label
          color={brand.textDim}
          size={13}
          kerning={2}
          style={{ marginBottom: 6 }}
        >
          History
        </Label>
        {[
          { date: "Mar 4", sets: "205×8 · 205×7 · 185×9", vol: "4,720", pr: true },
          { date: "Feb 28", sets: "195×8 · 195×8 · 185×8", vol: "4,600", pr: false },
          { date: "Feb 24", sets: "185×10 · 185×8 · 175×9", vol: "4,905", pr: false },
        ].map((h, i) => {
          const op = interpolate(frame, [76 + i * 8, 92 + i * 8], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <div
              key={h.date}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                paddingTop: 13,
                paddingBottom: 13,
                borderTop: i === 0 ? "none" : `1px solid ${brand.hairline}`,
                opacity: op,
              }}
            >
              <div>
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  <span
                    style={{
                      fontFamily: BARLOW,
                      fontWeight: 600,
                      fontSize: 17,
                      color: brand.textMain,
                    }}
                  >
                    {h.date} · Push Day
                  </span>
                  {h.pr ? <PRBadge brand={brand} scale={0.72} /> : null}
                </div>
                <div
                  style={{
                    fontFamily: BARLOW,
                    fontWeight: 400,
                    fontSize: 15,
                    color: brand.textDim,
                    marginTop: 2,
                  }}
                >
                  {h.sets}
                </div>
              </div>
              <span
                style={{
                  fontFamily: CONDENSED,
                  fontWeight: 700,
                  fontSize: 24,
                  color: brand.textSoft,
                }}
              >
                {h.vol}
              </span>
            </div>
          );
        })}
      </Card>
    </Screen>
  );
};

const SmallStat: React.FC<{ brand: Brand; label: string; value: string }> = ({
  brand,
  label,
  value,
}) => (
  <Card brand={brand} radius={20} style={{ flex: 1, padding: "18px 14px" }}>
    <Label color={brand.textDim} size={12.5} kerning={2}>
      {label}
    </Label>
    <div
      style={{
        fontFamily: CONDENSED,
        fontWeight: 700,
        fontSize: 42,
        color: brand.textMain,
        marginTop: 6,
      }}
    >
      {value}
    </div>
  </Card>
);
