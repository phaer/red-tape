# red-tape/modules — Discover and export NixOS/Darwin/Home modules
#
# Inputs: ../scan (discovery + flake context)
# Options: moduleTypeAliases
# Result: { nixosModules, darwinModules, homeModules, ... }
let
  inherit (builtins)
    all attrNames elem foldl' functionArgs
    intersectAttrs isFunction mapAttrs;

  defaultTypeAliases = { nixos = "nixosModules"; darwin = "darwinModules"; home = "homeModules"; };

  entryPath = e: if e.type == "directory" then e.path + "/default.nix" else e.path;

  buildModules = { discovered, allInputs, self, extraTypeAliases ? {} }:
    let
      publisherArgs = { flake = self; inputs = allInputs; };
      typeAliases = defaultTypeAliases // extraTypeAliases;

      isPublisherFn = fn:
        isFunction fn && (functionArgs fn) != {}
        && all (a: elem a [ "flake" "inputs" ]) (attrNames (functionArgs fn));

      importModule = e:
        let path = entryPath e; mod = import path;
        in if isPublisherFn mod
          then { _file = toString path; imports = [ (mod (intersectAttrs (functionArgs mod) publisherArgs)) ]; }
          else path;

      built = mapAttrs (_: mapAttrs (_: importModule)) discovered;
    in
    foldl' (acc: t:
      let alias = typeAliases.${t} or null;
      in if alias != null then acc // { ${alias} = built.${t}; } else acc
    ) {} (attrNames discovered);
in
{
  name = "modules";
  inputs = {
    scan = { path = "../scan"; };
  };
  options = {
    moduleTypeAliases = {
      type = { name = "attrs"; verify = v: if builtins.isAttrs v then null else "expected attrset"; };
      default = {};
    };
  };
  impl = { results, options, ... }:
    let
      inherit (results.scan) discovered self allInputs;
    in
    if discovered.modules != {} then
      buildModules {
        discovered = discovered.modules;
        inherit allInputs self;
        extraTypeAliases = options.moduleTypeAliases;
      }
    else
      {};
}
