# red-tape/formatter — Discover or default the formatter
#
# Inputs: ../scan, ../scope
# Result: { formatter = derivation; }
let
  inherit (builtins) addErrorContext functionArgs intersectAttrs;

  callFile = scope: path: extra:
    addErrorContext "while evaluating '${toString path}'" (
      let fn = import path;
      in fn (intersectAttrs (functionArgs fn) (scope // extra))
    );
in
{
  name = "formatter";
  inputs = {
    scan  = { path = "../scan"; };
    scope = { path = "../scope"; };
  };
  impl = { results, ... }:
    let
      s = results.scope;
      found = results.scan.discovered;
      pkgs = s.pkgs;
      formatter =
        if found.formatter != null then callFile s.scope found.formatter {}
        else pkgs.nixfmt-tree or pkgs.nixfmt or (throw "red-tape: no formatter.nix and nixfmt-tree unavailable");
    in
    { inherit formatter; };
}
