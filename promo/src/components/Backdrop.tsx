import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Brand } from "../brand";

/** Deep stage background with a slow-breathing brand glow and vignette. */
export const Backdrop: React.FC<{ brand: Brand; intensity?: number }> = ({
  brand,
  intensity = 1,
}) => {
  const frame = useCurrentFrame();
  const breathe = interpolate(
    Math.sin((frame / 90) * Math.PI),
    [-1, 1],
    [0.82, 1.08],
  );

  return (
    <AbsoluteFill style={{ background: brand.stageBg }}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse 78% 52% at 50% 42%, ${brand.stageGlow}, transparent 70%)`,
          opacity: breathe * intensity,
        }}
      />
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse 42% 26% at 50% 96%, ${brand.stageGlow}, transparent 72%)`,
          opacity: 0.55 * intensity,
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse 90% 70% at 50% 50%, transparent 42%, rgba(0,0,0,0.62) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};
