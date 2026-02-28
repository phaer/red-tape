# /checks — Per-system user-defined checks
#
# Only handles checks from the checks/ directory.
# Auto-checks from packages/devshells are assembled by the entry point.

let
  filterPlatforms = import ../lib/filter-platforms.nix;
  mkModule = import ../lib/mk-per-system-module.nix;
in
mkModule {
  name = "checks";
  postProcess = { system, built, ... }: {
    checks = filterPlatforms system built;
  };
}
