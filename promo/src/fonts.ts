import { continueRender, delayRender, staticFile } from "remotion";

/**
 * Loads the app's own Barlow faces before the first frame is rendered.
 * Remotion holds rendering via delayRender() until every face resolves.
 */
const faces: Array<[string, string, string]> = [
  ["Barlow", "fonts/Barlow-Regular.ttf", "400"],
  ["Barlow", "fonts/Barlow-Medium.ttf", "500"],
  ["Barlow", "fonts/Barlow-SemiBold.ttf", "600"],
  ["Barlow", "fonts/Barlow-Bold.ttf", "700"],
  ["Barlow Condensed", "fonts/BarlowCondensed-Medium.ttf", "500"],
  ["Barlow Condensed", "fonts/BarlowCondensed-SemiBold.ttf", "600"],
  ["Barlow Condensed", "fonts/BarlowCondensed-Bold.ttf", "700"],
  ["Barlow Condensed", "fonts/BarlowCondensed-ExtraBold.ttf", "800"],
];

let started = false;

export const loadFonts = () => {
  if (started) return;
  started = true;

  const handle = delayRender("Loading Barlow");
  Promise.all(
    faces.map(([family, path, weight]) => {
      const face = new FontFace(family, `url(${staticFile(path)})`, { weight });
      return face.load().then((loaded) => {
        document.fonts.add(loaded);
      });
    }),
  )
    .then(() => continueRender(handle))
    .catch(() => continueRender(handle));
};

export const CONDENSED = "'Barlow Condensed', 'Barlow', sans-serif";
export const BARLOW = "'Barlow', sans-serif";
