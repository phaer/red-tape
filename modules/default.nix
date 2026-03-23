# red-tape — Composable adios module tree
#
# Each sub-module handles one concern. The top-level module aggregates
# results so adios-flake's internal collectors can route them.
let
  default = {
    name = "red-tape";
    outputs = {
      modules = {
        type = "attrset";
        scope = "flake";
      };
    };
    inputs = {
      packages = {
        path = "./packages";
      };
      devshells = {
        path = "./devshells";
      };
      formatter = {
        path = "./formatter";
      };
      checks = {
        path = "./checks";
      };
      hosts = {
        path = "./hosts";
      };
      modules = {
        path = "./modules";
      };
      templates = {
        path = "./templates";
      };
      lib = {
        path = "./lib";
      };
    };
    impl =
      { results, ... }:
      builtins.foldl' (acc: r: acc // (builtins.removeAttrs r [ "autoChecks" ])) { } (
        builtins.attrValues results
      );
    modules = {
      scan = import ./scan.nix;
      scope = import ./scope.nix;
      packages = import ./packages.nix;
      devshells = import ./devshells.nix;
      formatter = import ./formatter.nix;
      checks = import ./checks.nix;
      hosts = import ./hosts.nix;
      modules = import ./modules.nix;
      templates = import ./templates.nix;
      lib = import ./lib.nix;
      contrib = import ./contrib.nix;
    };
  };
in
{
  redTape =
    builtins.removeAttrs default.modules [
      "modules"
      "contrib"
    ]
    // {
      inherit default;
      home-manager = import ../contrib/home-manager.nix;
      darwin = import ../contrib/darwin.nix;
      system-manager = import ../contrib/system-manager.nix;
    };
}
