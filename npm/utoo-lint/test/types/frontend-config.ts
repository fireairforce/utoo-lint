import { defineConfig } from "@utoo/lint/config";
import frontend from "@utoo/lint/configs/frontend";

export default defineConfig({
  rules: {
    ...frontend.rules,
  },
});
