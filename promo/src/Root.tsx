import React from "react";
import { Composition } from "remotion";
import { Promo, TOTAL_FRAMES } from "./Promo";
import { TITAN, VALKYRIE } from "./brand";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="TitanPromo"
        component={Promo}
        durationInFrames={TOTAL_FRAMES}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{ brand: TITAN }}
      />
      <Composition
        id="ValkyriePromo"
        component={Promo}
        durationInFrames={TOTAL_FRAMES}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{ brand: VALKYRIE }}
      />
    </>
  );
};
