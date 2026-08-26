// keep leading default comment
import UnusedDefault from "default-package";   // keep trailing default comment
import { UnusedNamed } from "named-package";
import * as UnusedNamespace from "namespace-package";
import type { UnusedType } from "type-package";
import /* keep block */ {
  // keep line
  UnusedCommented,
} from "commented-package";
import {
  Used,
  UnusedMultiline,
  // keep partial comment
  UsedToo,
} from "mixed-package";

console.log(Used, UsedToo);
