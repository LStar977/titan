import React from "react";
import { AbsoluteFill } from "remotion";
import { Brand } from "../brand";

export const PHONE_W = 660;
export const PHONE_H = 1340;
const BEZEL = 13;

/** Device shell with the app's background inside. */
export const Phone: React.FC<{
  brand: Brand;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ brand, children, style }) => {
  return (
    <div
      style={{
        width: PHONE_W,
        height: PHONE_H,
        borderRadius: 74,
        background: "#08080C",
        padding: BEZEL,
        boxShadow: `0 60px 120px rgba(0,0,0,0.65), 0 0 0 1px ${
          brand.isLight ? "rgba(255,255,255,0.14)" : "rgba(255,255,255,0.07)"
        }`,
        position: "relative",
        ...style,
      }}
    >
      <div
        style={{
          width: "100%",
          height: "100%",
          borderRadius: 62,
          background: brand.bg,
          overflow: "hidden",
          position: "relative",
        }}
      >
        {children}
        {/* Dynamic Island */}
        <div
          style={{
            position: "absolute",
            top: 18,
            left: "50%",
            transform: "translateX(-50%)",
            width: 172,
            height: 46,
            borderRadius: 23,
            background: "#08080C",
          }}
        />
        {/* Home indicator */}
        <div
          style={{
            position: "absolute",
            bottom: 14,
            left: "50%",
            transform: "translateX(-50%)",
            width: 200,
            height: 7,
            borderRadius: 4,
            background: brand.isLight
              ? "rgba(0,0,0,0.28)"
              : "rgba(255,255,255,0.30)",
          }}
        />
      </div>
    </div>
  );
};

/** Screen content padded below the status bar area. */
export const Screen: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => (
  <AbsoluteFill style={{ padding: "86px 30px 0 30px" }}>{children}</AbsoluteFill>
);
