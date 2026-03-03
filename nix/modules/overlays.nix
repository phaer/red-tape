# red-tape/overlays — Discover and build overlay expressions
#
# Inputs: ../scan (discovery + flake context)
# Result: { overlays = { name = overlay-fn; }; }
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
  name = "overlays";
  inputs = {
    scan = { path = "../scan"; };
  };
  impl = { results, ... }:
    let
      inherit (results.scan) discovered self allInputs;
      agnostic = { flake = self; inputs = allInputs; };
    in
    if discovered.overlays != {} then
      { overlays = buildAll agnostic discovered.overlays; }
    else
      {};
}
