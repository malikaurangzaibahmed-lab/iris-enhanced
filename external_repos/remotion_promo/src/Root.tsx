import "./index.css";
import { Composition } from "remotion";
import { IrisPromo } from "./IrisPromo";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="IrisPromo"
      component={IrisPromo}
      durationInFrames={240}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
