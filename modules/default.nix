# red-tape — Composable adios module tree
#
# Each sub-module handles one concern. The top-level module aggregates
# results so adios-flake's _collector/_flake can route them.
let
  strip = m: builtins.removeAttrs m [ "name" ];

  default = {
    name = "red-tape";
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
      scan = strip (import ./scan.nix { discover = import ../lib/discover.nix; });
      scope = strip (import ./scope.nix);
      packages = strip (import ./packages.nix);
      devshells = strip (import ./devshells.nix);
      formatter = strip (import ./formatter.nix);
      checks = strip (import ./checks.nix);
      hosts = strip (import ./hosts.nix);
      modules = strip (import ./modules.nix);
      templates = strip (import ./templates.nix);
      lib = strip (import ./lib.nix);
      contrib = strip (import ./contrib.nix);
    };
  };
in
{
  redTape = builtins.removeAttrs default.modules [ "modules" "contrib" ] // {
    inherit default;
    home-manager = import ../contrib/home-manager.nix;
    darwin = import ../contrib/darwin.nix;
    system-manager = import ../contrib/system-manager.nix;
  };
}
