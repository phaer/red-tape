# red-tape/checks — Discover checks + auto-checks from packages/devshells/hosts
let
  inherit (import ../lib/internal.nix) buildAll filterPlatforms withPrefix scanEntries;
  inherit (builtins)
    attrNames
    concatMap
    listToAttrs
    map
    ;
in
{
  name = "checks";
  inputs = {
    scan = {
      path = "../scan";
    };
    scope = {
      path = "../scope";
    };
    packages = {
      path = "../packages";
    };
    devshells = {
      path = "../devshells";
    };
    formatter = {
      path = "../formatter";
    };
    hosts = {
      path = "../hosts";
    };
  };
  impl =
    { results, ... }:
    let
      s = results.scope;
      system = s.system;
      src = results.scan.resolvedSrc;
      packages = results.packages.packages;
      devShells = results.devshells.devShells;
      formatter = results.formatter.formatter;
      hostResult = results.hosts;

      found = scanEntries { dir = src + "/checks"; };
      userChecks = filterPlatforms system (buildAll s.scope found);

      pkgChecks =
        withPrefix "pkgs-" packages
        // listToAttrs (
          concatMap (
            pname:
            let
              tests = filterPlatforms system (packages.${pname}.passthru.tests or { });
            in
            map (t: {
              name = "pkgs-${pname}-${t}";
              value = tests.${t};
            }) (attrNames tests)
          ) (attrNames packages)
        );

      devshellChecks = withPrefix "devshell-" devShells;

      hostAutoChecks =
        let
          ac = hostResult.autoChecks or null;
        in
        if ac != null then ac system else { };
    in
    {
      checks =
        hostAutoChecks // pkgChecks // { pkgs-formatter = formatter; } // devshellChecks // userChecks;
    };
}
