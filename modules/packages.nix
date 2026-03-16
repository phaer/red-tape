# red-tape/packages — Discover and build packages
let
  inherit (import ../lib/utils.nix) buildAll filterPlatforms;
  inherit (import ../lib/discover.nix) optional optionalDefault optionalSingle;
in
{
  name = "packages";
  inputs = {
    scan = {
      path = "../scan";
    };
    scope = {
      path = "../scope";
    };
    formatter = {
      path = "../formatter";
    };
  };
  impl =
    { results, ... }:
    let
      s = results.scope;
      src = results.scan.resolvedSrc;
      found =
        optionalDefault (src + "/packages")
        // optional (src + "/packages")
        // optionalSingle (src + "/package.nix") "default";
    in
    {
      packages = filterPlatforms s.system (
        buildAll s.scope found // { formatter = results.formatter.formatter; }
      );
    };
}
