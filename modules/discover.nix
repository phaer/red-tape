# discover.nix — Filesystem discovery (pure function, not an adios module)
#
# Scans the project source tree and returns paths to discovered files.
# Does NOT import anything — actual imports happen in per-system modules.
#
# This is a plain function, not an adios module, because:
# - It has no dependencies on other modules
# - Its results need to be passed as options to per-system modules
# - In adios, data flows through options, not impl results

let
  scanDir = import ../lib/scan-dir.nix;

  inherit (builtins) pathExists;

  # Return a single-entry attrset if the path exists, else empty
  optionalFile = path: name:
    if pathExists path then
      { ${name} = { inherit path; type = "file"; }; }
    else
      {};

  optionalPath = path:
    if pathExists path then path else null;

in
src: {
  packages =
    scanDir (src + "/packages")
    // optionalFile (src + "/package.nix") "default";

  devshells =
    scanDir (src + "/devshells")
    // optionalFile (src + "/devshell.nix") "default";

  checks = scanDir (src + "/checks");

  formatter = optionalPath (src + "/formatter.nix");

  lib = optionalPath (src + "/lib/default.nix");

  # Phase 2: hosts, modules, templates
  hosts = {};
  modules = {};
  templates = {};
}
