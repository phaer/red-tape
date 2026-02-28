# /packages — Per-system package builder

let
  filterPlatforms = import ../lib/filter-platforms.nix;
  mkModule = import ../lib/mk-per-system-module.nix;
in
mkModule {
  name = "packages";
  postProcess = { system, built, ... }:
    let filtered = filterPlatforms system built;
    in { packages = built; filteredPackages = filtered; };
}
