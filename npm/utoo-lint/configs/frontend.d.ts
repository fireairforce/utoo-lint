import type { ConfigObject } from "../index.js";

declare const frontend: ConfigObject & {
  readonly $schema: string;
  readonly rules: NonNullable<ConfigObject["rules"]>;
};

export default frontend;
