import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";

/** Cold open: the wordmark forges itself out of the dark. */
export const Intro: React.FC<{ brand: Brand }> = ({ brand }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = spring({ frame: frame - 6, fps, config: { damping: 200 } });
  const kerning = interpolate(enter, [0, 1], [64, brand.wordmarkKerning * 4]);
  const markOpacity = interpolate(frame, [6, 30], [0, 1], {
    extrapolateRight: "clamp",
  });
  const blur = interpolate(frame, [6, 34], [16, 0], {
    extrapolateRight: "clamp",
  });

  const ruleW = interpolate(frame, [30, 56], [0, 300], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const taglineOp = interpolate(frame, [42, 64], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const taglineY = interpolate(frame, [42, 64], [18, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const drift = interpolate(frame, [0, 100], [1.06, 1.0]);

  return (
    <AbsoluteFill>
      <Backdrop brand={brand} />
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          transform: `scale(${drift})`,
        }}
      >
        <div
          style={{
            fontFamily: CONDENSED,
            fontWeight: 800,
            fontSize: 190,
            letterSpacing: kerning,
            // kerning adds trailing space; nudge back so it reads centred
            marginLeft: kerning,
            color: brand.isLight ? "#FFFFFF" : brand.textMain,
            opacity: markOpacity,
            filter: `blur(${blur}px)`,
            textShadow: `0 0 70px ${brand.primary}88, 0 0 140px ${brand.primary}44`,
            lineHeight: 1,
          }}
        >
          {brand.wordmark}
        </div>

        <div
          style={{
            width: ruleW,
            height: 3,
            marginTop: 34,
            background: `linear-gradient(90deg, transparent, ${brand.primary}, transparent)`,
          }}
        />

        <div
          style={{
            fontFamily: BARLOW,
            fontWeight: 600,
            fontSize: 34,
            letterSpacing: 9,
            color: brand.isLight ? "#F6D9E4" : brand.textDim,
            marginTop: 30,
            marginLeft: 9,
            opacity: taglineOp,
            transform: `translateY(${taglineY}px)`,
          }}
        >
          {brand.tagline}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
