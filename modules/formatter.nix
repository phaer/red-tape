# red-tape/formatter — Discover or default the formatter
let
  inherit (import ../lib/utils.nix) callFile;
  inherit (builtins) pathExists;
in
{
  name = "formatter";
  inputs = {
    scan = {
      path = "../scan";
    };
    scope = {
      path = "../scope";
    };
  };
  impl =
    { results, ... }:
    let
      s = results.scope;
      src = results.scan.resolvedSrc;
      formatterPath =
        let
          p = src + "/formatter.nix";
        in
        if pathExists p then p else null;
      pkgs = s.pkgs;
      formatter =
        if formatterPath != null then
          callFile s.scope formatterPath { }
        else
          pkgs.nixfmt-tree or pkgs.nixfmt or (throw "red-tape: no formatter.nix and nixfmt-tree unavailable");
    in
    {
      inherit formatter;
    };
}
