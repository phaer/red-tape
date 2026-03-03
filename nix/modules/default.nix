# red-tape — Composable adios module tree
#
# This is the top-level module that wires together all sub-modules.
# It has an impl that aggregates results from all sub-modules into a
# single attrset that adios-flake's _collector and _flake can route.
#
# Usage (à la carte with mkFlake):
#   modules = [ red-tape.modules.default ];
#   config."/red-tape/scan" = { src = self; };
#   config."/red-tape/scope" = { inherit self inputs; };
#   ...
{ discover, callFile, buildAll, filterPlatforms, withPrefix
, buildModules, buildHosts, entryPath
}:

let
  scanModule      = import ./scan.nix { inherit discover; };
  scopeModule     = import ./scope.nix;
  packagesModule  = import ./packages.nix { inherit buildAll filterPlatforms; };
  devshellsModule = import ./devshells.nix { inherit buildAll; };
  checksModule    = import ./checks.nix { inherit buildAll filterPlatforms withPrefix; };
  formatterModule = import ./formatter.nix { inherit callFile; };
  hostsModule     = import ./hosts.nix { inherit buildHosts; };
  modulesModule   = import ./modules.nix { inherit buildModules; };
  overlaysModule  = import ./overlays.nix { inherit buildAll; };
  templatesModule = import ./templates.nix;
  libModule       = import ./lib.nix;

  stripName = m: builtins.removeAttrs m [ "name" ];
in
{
  # The top-level adios module tree.
  # When used as a native module in adios-flake, its impl aggregates all
  # sub-module results so the _collector/_flake can route them.
  default = {
    name = "red-tape";
    inputs = {
      packages  = { path = "./packages"; };
      devshells = { path = "./devshells"; };
      checks    = { path = "./checks"; };
      formatter = { path = "./formatter"; };
      hosts     = { path = "./hosts"; };
      modules   = { path = "./modules"; };
      overlays  = { path = "./overlays"; };
      templates = { path = "./templates"; };
      lib       = { path = "./lib"; };
    };
    impl = { results, ... }:
      # Merge all sub-module results into a single attrset.
      # Each sub-module returns e.g. { packages = {...}; } or
      # { nixosConfigurations = {...}; darwinConfigurations = {...}; }
      # We merge them, stripping internal keys like autoChecks.
      builtins.foldl' (acc: r:
        acc // (builtins.removeAttrs r [ "autoChecks" ])
      ) {} (builtins.attrValues results);
    modules = {
      scan      = stripName scanModule;
      scope     = stripName scopeModule;
      packages  = stripName packagesModule;
      devshells = stripName devshellsModule;
      checks    = stripName checksModule;
      formatter = stripName formatterModule;
      hosts     = stripName hostsModule;
      modules   = stripName modulesModule;
      overlays  = stripName overlaysModule;
      templates = stripName templatesModule;
      lib       = stripName libModule;
    };
  };

  # Individual sub-modules for direct use.
  inherit scanModule scopeModule;
  packages  = packagesModule;
  devshells = devshellsModule;
  checks    = checksModule;
  formatter = formatterModule;
  hosts     = hostsModule;
  modules   = modulesModule;
  overlays  = overlaysModule;
  templates = templatesModule;
  lib       = libModule;
}
