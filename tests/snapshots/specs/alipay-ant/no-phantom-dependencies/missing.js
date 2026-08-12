import declared from "declared-package";
import missing from "utoo-snapshot-missing-package";

const scoped = require("@utoo-snapshot/missing/subpath");
console.log(declared, missing, scoped);
