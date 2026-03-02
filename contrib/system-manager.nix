# contrib/system-manager.nix — system-manager host support as a standalone module
#
# Scans hosts/ for system-configuration.nix files and produces
# systemConfigs.<hostname> outputs. Does not replace the core hosts module —
# both run independently over the same hosts/ directory.
#
# Usage:
#   outputs = inputs:
#     let rt = inputs.red-tape.lib;
#     in rt {
#       inherit inputs;
#       extraModules.system-manager = import (inputs.red-tape + "/contrib/system-manager.nix") {
#         inherit (rt) adios;
#         scanHosts = rt._internal.scanHosts;
#       };
#     };

{ adios, scanHosts }:
let
  inherit (builtins) addErrorContext attrNames filter listToAttrs mapAttrs;
  types = adios.types;
in
{
  name = "system-manager";

  discover = src:
    scanHosts (src + "/hosts") [
      { type = "system-manager"; file = "system-configuration.nix"; }
    ];

  optionsFn = { discovered, flakeInputs, self, ... }:
    { discovered = discovered.system-manager; inherit flakeInputs self; };

  options = {
    discovered  = { type = types.attrs; default = {}; };
    flakeInputs = { type = types.attrs; default = {}; };
    self        = { type = types.any;   default = null; };
  };

  impl = { options, ... }:
    let
      inherit (options) flakeInputs self;
      allInputs   = flakeInputs // (if self != null then { inherit self; } else {});
      specialArgs = { flake = self; inputs = allInputs; };
      system-manager = flakeInputs.system-manager
        or (throw "red-tape: system-manager contrib module needs inputs.system-manager");

      loadHost = hostName: hostInfo:
        addErrorContext "while building system-manager host '${hostName}'" (
          system-manager.lib.makeSystemConfig {
            modules     = [ hostInfo.configPath ];
            specialArgs = specialArgs // { inherit hostName; };
          }
        );
    in {
      systemConfigs = mapAttrs loadHost options.discovered;
    };
}
