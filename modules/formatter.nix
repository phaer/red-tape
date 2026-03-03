# red-tape/formatter — Discover or default the formatter
let
  inherit (import ../lib/utils.nix) callFile;
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
      found = results.scan.discovered;
      pkgs = s.pkgs;
      formatter =
        if found.formatter != null then
          callFile s.scope found.formatter { }
        else
          pkgs.nixfmt-tree or pkgs.nixfmt or (throw "red-tape: no formatter.nix and nixfmt-tree unavailable");
    in
    {
      inherit formatter;
    };
}
