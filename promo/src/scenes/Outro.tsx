import React from "react";
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Backdrop } from "../components/Backdrop";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";

/** Closing card: icon, name, and where to get it. */
export const Outro: React.FC<{ brand: Brand }> = ({ brand }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const iconPop = spring({
    frame: frame - 6,
    fps,
    config: { damping: 13, stiffness: 130 },
  });
  const nameOp = interpolate(frame, [22, 42], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const ruleW = interpolate(frame, [40, 64], [0, 360], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const ctaOp = interpolate(frame, [52, 74], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const ctaY = interpolate(frame, [52, 74], [22, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill>
      <Backdrop brand={brand} intensity={1.25} />
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          paddingBottom: 40,
        }}
      >
        <div
          style={{
            transform: `scale(${iconPop})`,
            borderRadius: 88,
            overflow: "hidden",
            width: 340,
            height: 340,
            boxShadow: `0 40px 90px rgba(0,0,0,0.6), 0 0 90px ${brand.primary}55`,
          }}
        >
          <Img
            src={staticFile(brand.icon)}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
          />
        </div>

        <div
          style={{
            fontFamily: CONDENSED,
            fontWeight: 800,
            fontSize: 128,
            letterSpacing: brand.wordmarkKerning * 3,
            marginLeft: brand.wordmarkKerning * 3,
            color: "#FFFFFF",
            marginTop: 46,
            opacity: nameOp,
            textShadow: `0 0 60px ${brand.primary}77`,
            lineHeight: 1,
          }}
        >
          {brand.wordmark}
        </div>

        <div
          style={{
            fontFamily: BARLOW,
            fontWeight: 500,
            fontSize: 32,
            letterSpacing: 5,
            color: brand.isLight ? "#F6D9E4" : brand.textDim,
            marginTop: 14,
            marginLeft: 5,
            opacity: nameOp,
          }}
        >
          {brand.storeName.toUpperCase()}
        </div>

        <div
          style={{
            width: ruleW,
            height: 2,
            marginTop: 44,
            background: `linear-gradient(90deg, transparent, ${brand.primary}, transparent)`,
          }}
        />

        <div
          style={{
            opacity: ctaOp,
            transform: `translateY(${ctaY}px)`,
            marginTop: 44,
            textAlign: "center",
          }}
        >
          <div
            style={{
              fontFamily: CONDENSED,
              fontWeight: 800,
              fontSize: 60,
              letterSpacing: 3,
              color: "#FFFFFF",
            }}
          >
            {brand.closingLine}
          </div>
          <div
            style={{
              fontFamily: BARLOW,
              fontWeight: 500,
              fontSize: 27,
              letterSpacing: 2,
              color: brand.isLight ? "#E8B9CC" : brand.textDim,
              marginTop: 14,
            }}
          >
            Coming soon to the App Store
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
