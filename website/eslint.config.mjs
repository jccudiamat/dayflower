import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // react-three-fiber drives a render loop by mutating the camera, refs and
    // uniform objects inside useFrame, sixty times a second. That is the whole
    // library's model, and it is deliberately outside React's: allocating new
    // objects per frame instead would churn the GC during the one part of the
    // page where dropped frames are visible.
    //
    // The React Compiler rules encode React's model, so they flag every line of
    // it. Narrowed to this directory rather than switched off globally, so the
    // rest of the site keeps the checks.
    files: ["app/world/**/*.tsx"],
    rules: {
      "react-hooks/immutability": "off",
      "react-hooks/preserve-manual-memoization": "off",
      "react-hooks/purity": "off",
      "react-hooks/set-state-in-effect": "off",
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
