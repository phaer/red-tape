# red-tape/devshells — Build devshells from discovered expressions
#
# Inputs: ../scan (discovery), ../scope (per-system eval scope)
# Result: { devShells = { name = derivation; }; }
let
  inherit (builtins)
    addErrorContext functionArgs intersectAttrs mapAttrs;

  callFile = scope: path: extra:
    addErrorContext "while evaluating '${toString path}'" (
      let fn = import path;
      in fn (intersectAttrs (functionArgs fn) (scope // extra))
    );

  entryPath = e: if e.type == "directory" then e.path + "/default.nix" else e.path;

  buildAll = scope: mapAttrs (pname: e: callFile scope (entryPath e) { inherit pname; });
in
{
  name = "devshells";
  inputs = {
    scan  = { path = "../scan"; };
    scope = { path = "../scope"; };
  };
  impl = { results, ... }:
    { devShells = buildAll results.scope.scope results.scan.discovered.devshells; };
}
