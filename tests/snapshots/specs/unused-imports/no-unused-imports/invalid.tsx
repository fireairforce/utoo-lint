import UnusedDefault, {
  Used,
  type UnusedType,
  Kept as UsedAlias,
} from "package";
import "side-effect";

export const View = () => <Used value={UsedAlias} />;
