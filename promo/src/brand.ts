/**
 * Palettes mirrored from Titan/Brand.swift so the video matches the app exactly.
 * One video definition, two brands — same trick the apps use.
 */

export type Brand = {
  key: "titan" | "valkyrie";
  wordmark: string;
  plainName: string;
  wordmarkKerning: number;
  storeName: string;
  tagline: string;
  icon: string;
  rankNames: string[];
  recordsWord: string;
  prWord: string;
  isLight: boolean;
  closingLine: string;

  bg: string;
  surface: string;
  surface2: string;
  surface3: string;
  primary: string;
  primaryBright: string;
  primaryDeep: string;
  primaryMid: string;
  glow: string;
  textMain: string;
  textSoft: string;
  textDim: string;
  textFaint: string;
  success: string;
  sheetBg: string;
  tabBarBg: string;
  outline: string;
  heatBody: string;
  hairline: string;
  strokeStrong: string;
  /** Colour of the deep page backdrop behind the phone. */
  stageBg: string;
  stageGlow: string;
};

export const TITAN: Brand = {
  key: "titan",
  wordmark: "TITΛN",
  plainName: "TITAN",
  wordmarkKerning: 5,
  storeName: "Gym Workout Tracker",
  tagline: "STRENGTH, TRACKED.",
  icon: "icons/titan.png",
  rankNames: ["BRONZE", "IRON", "SPARTAN", "TITAN"],
  recordsWord: "PRs",
  prWord: "PR",
  isLight: false,
  closingLine: "BEGIN THE CLIMB",

  bg: "#0A0A0F",
  surface: "#131320",
  surface2: "#1C1C2E",
  surface3: "#2A2A3E",
  primary: "#8B5CF6",
  primaryBright: "#A78BFA",
  primaryDeep: "#5B21B6",
  primaryMid: "#6D28D9",
  glow: "#C4B5FD",
  textMain: "#EDEDF4",
  textSoft: "#C7C7D6",
  textDim: "#8E8EA3",
  textFaint: "#62627A",
  success: "#34D399",
  sheetBg: "#10101B",
  tabBarBg: "#0C0C13",
  outline: "#3A3A4E",
  heatBody: "#232333",
  hairline: "rgba(255,255,255,0.05)",
  strokeStrong: "rgba(255,255,255,0.08)",
  stageBg: "#07070B",
  stageGlow: "rgba(139,92,246,0.20)",
};

export const VALKYRIE: Brand = {
  key: "valkyrie",
  wordmark: "VALKYRIE",
  plainName: "VALKYRIE",
  wordmarkKerning: 3,
  storeName: "Gym Girl Workout Log",
  tagline: "RISE, EVERY SESSION.",
  icon: "icons/valkyrie.png",
  rankNames: ["EMBER", "SHIELDMAIDEN", "VALKYRIE", "IMMORTAL"],
  recordsWord: "Records",
  prWord: "BEST",
  isLight: true,
  closingLine: "BEGIN THE ASCENT",

  bg: "#FFF8F6",
  surface: "#FFFFFF",
  surface2: "#FAEEF1",
  surface3: "#F4E3E7",
  primary: "#EC4899",
  primaryBright: "#FF3D8B",
  primaryDeep: "#BE185D",
  primaryMid: "#DB2777",
  glow: "#FF3D8B",
  textMain: "#241A20",
  textSoft: "#4A3A42",
  textDim: "#8A7480",
  textFaint: "#B8A5AE",
  success: "#059669",
  sheetBg: "#FDF2F5",
  tabBarBg: "#FFFDFC",
  outline: "#E8B4C4",
  heatBody: "#F4E3E7",
  hairline: "rgba(0,0,0,0.06)",
  strokeStrong: "rgba(0,0,0,0.09)",
  stageBg: "#1A0E14",
  stageGlow: "rgba(236,72,153,0.28)",
};
