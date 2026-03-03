# red-tape/checks — Build checks + auto-checks from packages/devshells/hosts
#
# Inputs: ../scan, ../scope, ../packages, ../devshells, ../hosts
# Result: { checks = { name = derivation; }; }
let
  inherit (builtins)
    addErrorContext attrNames concatMap elem filter
    functionArgs intersectAttrs listToAttrs map mapAttrs;

  callFile = scope: path: extra:
    addErrorContext "while evaluating '${toString path}'" (
      let fn = import path;
      in fn (intersectAttrs (functionArgs fn) (scope // extra))
    );

  entryPath = e: if e.type == "directory" then e.path + "/default.nix" else e.path;

  buildAll = scope: mapAttrs (pname: e: callFile scope (entryPath e) { inherit pname; });

  filterPlatforms = system: a:
    listToAttrs (filter (x: x != null) (map (n:
      let p = a.${n}.meta.platforms or [];
      in if p == [] || elem system p then { name = n; value = a.${n}; } else null
    ) (attrNames a)));

  withPrefix = pre: a:
    listToAttrs (map (n: { name = "${pre}${n}"; value = a.${n}; }) (attrNames a));
in
{
  name = "checks";
  inputs = {
    scan      = { path = "../scan"; };
    scope     = { path = "../scope"; };
    packages  = { path = "../packages"; };
    devshells = { path = "../devshells"; };
    hosts     = { path = "../hosts"; };
  };
  impl = { results, ... }:
    let
      s = results.scope;
      system = s.system;
      found = results.scan.discovered;
      packages = results.packages.packages;
      devShells = results.devshells.devShells;
      hostResult = results.hosts;

      # User-written checks
      userChecks = filterPlatforms system (buildAll s.scope found.checks);

      # Auto-checks: packages as checks + passthru.tests
      pkgChecks = withPrefix "pkgs-" packages
        // listToAttrs (concatMap (pname:
          let tests = filterPlatforms system (packages.${pname}.passthru.tests or {});
          in map (t: { name = "pkgs-${pname}-${t}"; value = tests.${t}; }) (attrNames tests)
        ) (attrNames packages));

      # Auto-checks: devshells as checks
      devshellChecks = withPrefix "devshell-" devShells;

      # Auto-checks: host toplevel builds for this system
      hostAutoChecks =
        let ac = hostResult.autoChecks or null;
        in if ac != null then ac system else {};
    in
    { checks = hostAutoChecks // pkgChecks // devshellChecks // userChecks; };
}
