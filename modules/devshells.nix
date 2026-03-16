# red-tape/devshells — Discover and build devshells
let
  inherit (import ../lib/utils.nix) buildAll;
  inherit (import ../lib/discover.nix) scanEntries;
in
{
  name = "devshells";
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
      src = results.scan.resolvedSrc;
      found = scanEntries { dir = src + "/devshells"; single = src + "/devshell.nix"; };
    in
    {
      devShells = buildAll results.scope.scope found;
    };
}
