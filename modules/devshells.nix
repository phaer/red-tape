# red-tape/devshells — Build devshells from discovered expressions
let
  inherit (import ../lib/utils.nix) buildAll;
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
    {
      devShells = buildAll results.scope.scope results.scan.discovered.devshells;
    };
}
