# red-tape/hosts — Discover and build host configurations
let
  inherit (import ../lib/internal.nix)
    scanHosts
    coreHostTypes
    buildHosts
    ;
in
{
  name = "hosts";
  inputs = {
    project = {
      path = "../project";
    };
    contrib = {
      path = "../contrib";
    };
  };
  impl =
    { results, ... }:
    let
      src = results.project.resolvedSrc;
      inherit (results.project)
        self
        inputs
        defaultSystem
        pkgsFor
        ;
      hostTypes = coreHostTypes ++ results.contrib.scanHostTypes;
      discovered = scanHosts (src + "/hosts") hostTypes;
    in
    if discovered != { } then
      buildHosts {
        inherit
          discovered
          inputs
          self
          defaultSystem
          pkgsFor
          ;
        extraHostTypes = results.contrib.hostTypes;
      }
    else
      {
        nixosConfigurations = { };
        autoChecks = _: { };
      };
}
