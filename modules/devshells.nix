# red-tape/devshells — Discover and build devshells
let
  inherit (import ../lib/utils.nix) buildAll;
  inherit (import ../lib/discover.nix) optional optionalDefault optionalSingle;
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
      found =
        optionalDefault (src + "/devshells")
        // optional (src + "/devshells")
        // optionalSingle (src + "/devshell.nix") "default";
    in
    {
      devShells = buildAll results.scope.scope found;
    };
}
