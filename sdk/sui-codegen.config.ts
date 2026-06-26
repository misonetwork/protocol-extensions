import type { SuiCodegenConfig } from "@mysten/codegen";

// Generates type-safe BCS structs + Move-call bindings from the local Move
// extension packages (siblings of this SDK). Generated from live source, so the
// bindings stay in lockstep with the on-chain ABI.
const config: SuiCodegenConfig = {
  output: "./src/contracts",
  packages: [
    { package: "@local-pkg/recording_credits", path: "../recording_credits" },
    { package: "@local-pkg/composition_credits", path: "../composition_credits" },
    { package: "@local-pkg/release_credits", path: "../release_credits" },
    { package: "@local-pkg/cover_art", path: "../cover_art" },
    { package: "@local-pkg/genre", path: "../genre" },
  ],
};

export default config;
