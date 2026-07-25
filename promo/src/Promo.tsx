import React from "react";
import {
  AbsoluteFill,
  interpolate,
  Sequence,
  useCurrentFrame,
} from "remotion";
import { Brand } from "./brand";
import { loadFonts } from "./fonts";
import { Intro } from "./scenes/Intro";
import { Outro } from "./scenes/Outro";
import { Stage, STAGE_FRAMES } from "./components/Stage";

export const INTRO_END = 100;
export const STAGE_START = 88;
export const STAGE_END = STAGE_START + STAGE_FRAMES; // 668
export const OUTRO_START = STAGE_END - 12; // 656
export const OUTRO_FRAMES = 124;
export const TOTAL_FRAMES = OUTRO_START + OUTRO_FRAMES; // 780 = 26s @30fps

const XFADE = 12;

export const Promo: React.FC<{ brand: Brand }> = ({ brand }) => {
  loadFonts();
  const frame = useCurrentFrame();

  const introOut = interpolate(
    frame,
    [INTRO_END - XFADE, INTRO_END],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const stageOp = interpolate(
    frame,
    [STAGE_START, STAGE_START + XFADE, STAGE_END - XFADE, STAGE_END],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const outroOp = interpolate(
    frame,
    [OUTRO_START, OUTRO_START + XFADE],
    [0, 1],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <AbsoluteFill style={{ background: brand.stageBg }}>
      <Sequence from={0} durationInFrames={INTRO_END}>
        <AbsoluteFill style={{ opacity: introOut }}>
          <Intro brand={brand} />
        </AbsoluteFill>
      </Sequence>

      <Sequence from={STAGE_START} durationInFrames={STAGE_FRAMES}>
        <AbsoluteFill style={{ opacity: stageOp }}>
          <Stage brand={brand} />
        </AbsoluteFill>
      </Sequence>

      <Sequence from={OUTRO_START} durationInFrames={OUTRO_FRAMES}>
        <AbsoluteFill style={{ opacity: outroOp }}>
          <Outro brand={brand} />
        </AbsoluteFill>
      </Sequence>
    </AbsoluteFill>
  );
};
