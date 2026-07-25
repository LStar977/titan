import React from "react";
import { Brand } from "../brand";
import { BARLOW, CONDENSED } from "../fonts";

/** Surface card matching the app's .card() modifier. */
export const Card: React.FC<{
  brand: Brand;
  radius?: number;
  border?: string;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}> = ({ brand, radius = 22, border, style, children }) => (
  <div
    style={{
      background: brand.surface,
      borderRadius: radius,
      border: `1.5px solid ${border ?? brand.hairline}`,
      ...style,
    }}
  >
    {children}
  </div>
);

/** Small kerned uppercase label — the app's SectionLabel. */
export const Label: React.FC<{
  children: React.ReactNode;
  color: string;
  size?: number;
  kerning?: number;
  weight?: number;
  style?: React.CSSProperties;
}> = ({ children, color, size = 15, kerning = 2, weight = 600, style }) => (
  <div
    style={{
      fontFamily: BARLOW,
      fontWeight: weight,
      fontSize: size,
      letterSpacing: kerning,
      color,
      textTransform: "uppercase",
      ...style,
    }}
  >
    {children}
  </div>
);

/** Condensed display type — headlines and big numbers. */
export const Display: React.FC<{
  children: React.ReactNode;
  color: string;
  size: number;
  weight?: number;
  kerning?: number;
  style?: React.CSSProperties;
}> = ({ children, color, size, weight = 800, kerning = 0, style }) => (
  <div
    style={{
      fontFamily: CONDENSED,
      fontWeight: weight,
      fontSize: size,
      letterSpacing: kerning,
      lineHeight: 1.0,
      color,
      ...style,
    }}
  >
    {children}
  </div>
);

export const Hexagon: React.FC<{
  size: number;
  fill: string;
  border?: string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ size, fill, border, children, style }) => (
  <div
    style={{
      width: size,
      height: size * 1.09,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      position: "relative",
      ...style,
    }}
  >
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: border ?? fill,
        clipPath:
          "polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%)",
      }}
    />
    <div
      style={{
        position: "absolute",
        inset: 2.5,
        background: fill,
        clipPath:
          "polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%)",
      }}
    />
    <div style={{ position: "relative" }}>{children}</div>
  </div>
);

/** The app's PR flame badge. */
export const PRBadge: React.FC<{ brand: Brand; scale?: number }> = ({
  brand,
  scale = 1,
}) => (
  <div
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 5 * scale,
      background: `linear-gradient(135deg, ${brand.primaryMid}, ${brand.primary})`,
      borderRadius: 999,
      padding: `${5 * scale}px ${12 * scale}px`,
      transform: `scale(${scale})`,
      transformOrigin: "left center",
      boxShadow: `0 0 ${26 * scale}px ${brand.primary}66`,
    }}
  >
    <span style={{ fontSize: 15, lineHeight: 1 }}>🔥</span>
    <span
      style={{
        fontFamily: BARLOW,
        fontWeight: 700,
        fontSize: 14,
        letterSpacing: 1.4,
        color: "#FFFFFF",
      }}
    >
      PR
    </span>
  </div>
);

/** Purple gradient call-to-action button. */
export const GradientCTA: React.FC<{
  brand: Brand;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ brand, children, style }) => (
  <div
    style={{
      background: `linear-gradient(100deg, ${brand.primaryDeep}, ${brand.primary})`,
      borderRadius: 18,
      padding: "20px 0",
      textAlign: "center",
      fontFamily: BARLOW,
      fontWeight: 700,
      fontSize: 19,
      letterSpacing: 2.4,
      color: "#FFFFFF",
      boxShadow: `0 14px 34px ${brand.primary}44`,
      ...style,
    }}
  >
    {children}
  </div>
);

export const Divider: React.FC<{ brand: Brand; inset?: number }> = ({
  brand,
  inset = 0,
}) => (
  <div
    style={{
      height: 1,
      background: brand.hairline,
      marginLeft: inset,
    }}
  />
);
