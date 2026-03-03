# red-tape/packages — Build packages from discovered expressions
#
# Inputs: ../scan (discovery), ../scope (per-system eval scope)
# Result: { packages = { name = derivation; }; }
let
  inherit (builtins)
    addErrorContext elem filter functionArgs
    intersectAttrs listToAttrs map mapAttrs;

  callFile = scope: path: extra:
    addErrorContext "while evaluating '${toString path}'" (
      let fn = import path;
      in fn (intersectAttrs (functionArgs fn) (scope // extra))
    );

  entryPath = e: if e.type == "directory" then e.path + "/default.nix" else e.path;

  buildAll = scope: mapAttrs (pname: e: callFile scope (entryPath e) { inherit pname; });

  filterPlatforms = system: a:
    listToAttrs (filter (x: x != null) (map (n:
      let p = a.${n}.meta.platforms or [];
      in if p == [] || elem system p then { name = n; value = a.${n}; } else null
    ) (builtins.attrNames a)));
in
{
  name = "packages";
  inputs = {
    scan  = { path = "../scan"; };
    scope = { path = "../scope"; };
  };
  impl = { results, ... }:
    let
      s = results.scope;
      found = results.scan.discovered;
    in
    { packages = filterPlatforms s.system (buildAll s.scope found.packages); };
}
